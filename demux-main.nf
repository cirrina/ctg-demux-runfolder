
/* ===============================================================
  *      PARAMS FROM CONFIGS
  =============================================================== */

//  re-assign some params from nextflow.configs
// ----------------------------------------------------
//  project and run folders
runfolder           =  params.runFolder    //
runfolder_path      =  params.runfolder_path
workdir_nf          =  params.nextflow_workir
samplesheet         =  params.samplesheet           // name of simple sample sheet used for pipeline. Must includes file paths to fastq and bamsm, as well as species etc.
output_dir          =  params.output_dir
// multiqcreport       =  params.multiqcreport
ctg_qc_root         = params.ctg_qc_root
multiqcdir          =  params.multiqcdir
fastqcdir           =  params.fastqcdir
fastqscreendir      =  params.fastqscreendir

ctg_qc_dir          = "/projects/fs1/shared/ctg-qc/interop/" // copy multiqc to the ctg interop (replace if already present). This to sync demux-interop per runfolder to the ctg qc app

/* ===============================================================
  *       create output and logdirs
  =============================================================== */
// log file for nextflow .onComplete
logfile   =  file( workdir_nf + '/' + 'log.nextflow.complete' )


/* ===============================================================
  *       CHECKS FILES AND PARAMS
  =============================================================== */
//  Check params
if (runfolder     == '') {exit 1, "You must define a project_id in the nextflow.config"}
if (samplesheet   == '') {exit 1, "You must define a sample sheet path in the nextflow.config"}

// Check if files and directories exist
checkPathParamList = [
  workdir_nf,
  samplesheet
]
for (param in checkPathParamList) {
    if (param) {
	     file(param, checkIfExists: true)
    }
}



/* ===============================================================
  *       MESSAGES
  =============================================================== */

// Define messages to print and for logfiles
def msg_startup = """\
    Workflow execution parameters
    ---------------------------------
    runfolder               :  ${runfolder}
    samplesheet             :  ${samplesheet}
    output dir              :  ${output_dir}
    nextflow execution dir  :  ${baseDir}
    nextflow work dir       :  ${workDir}
   """
   .stripIndent()

println( msg_startup )


workflow.onComplete {

  def msg_completed = """\
  	Pipeline execution summary
  	---------------------------
  	Completed at : ${workflow.complete}
  	Duration     : ${workflow.duration}
  	Success      : ${workflow.success}
  	scriptFile   : ${workflow.scriptFile}
    exit status  : ${workflow.exitStatus}
  	errorMessage : ${workflow.errorMessage}
  	errorReport  :
  	"""
  	.stripIndent()
  def error = """\
		${workflow.errorReport}
	   """
  logfile.text = msg_startup.stripIndent()
  logfile.append( msg_completed.stripIndent() )
  logfile.append( error )

  println( msg_completed )
}


/* ===============================================================
  *    PROCESS SAMPLE SHEET & DEFINE CHANNELS (bcl2fastq [Data] samplesheet)
  =============================================================== */
// Read and process sample sheet. Save to SampleSheet-nexflow.csv
// samplesheet to be parsed as input channel (take everything below [Data] section).
sheet = file(params.samplesheet)
all_lines = sheet.readLines()
write_row = false // if next lines has sample info
sheet_nf = file("${project_dir}/SampleSheet-nexflow.csv")
sheet_nf.text=""

for ( line in all_lines ) {
  if ( write_row ) {
    sheet_nf.append(line + "\n")
  }
  if (line.contains("[Data]")) {
    write_row = true
  }
}

Channel
  .fromPath(sheet_nf)
  .splitCsv(header:true)
  .map { row -> tuple( row.Sample_ID, row.Sample_Project, row.fastq_1, row.fastq_2 ) }
  .tap{ infoall }
  .set { fastq_ch }

println " > Samples to process: "
println "[Sample_ID,fastq1,fastq2]"
infoall.subscribe { println "Info: $it" }



/* ===============================================================
  *      bcl2fastq
  =============================================================== */
process bcl2fastq {
    tag "${runfolder}"
    cpus params.cpu_high
    memory params.mem_high

    input:
    val "start"

    output:
    val "x" into bcl2fastq_complete

    script:
    if ( params.run_bcl2fastq )
      """
      bcl2fastq -R ${runfolder_path} \\
                --sample-sheet ${samplesheet} ${params.bcl2fastqarg} \\
                -r 1 \\
                -p $task.cpus  \\
                -w 1  \\
                --output-dir ${output_dir}          
       """
    else
       """
       echo "bcl2fastq skipped"
       """
}


/* ===============================================================
  *    --- CHECK FASTQ FILES ---
  =============================================================== */
// check if all expected files provided by samplesheet (columns fastq_1 and fastq_2) in fastq_input_dir
// if paired run, check bit
process checkfiles_fastq {

  tag  "${pid}__${sid}"
  cpus params.cpu_min
  memory params.mem_min

  input:
  set sid, pid, read1, read2, from fastq_ch

  output:
  val "x" into checkfiles_fastq_complete_ch
  set sid, pid, read1, read2 into fastqc_ch


  script:
  if ( params.paired_global && params.run_check_fastq )
    """
    file1=\$(find ${fastq_input_dir}/${pid} -type f -name ${read1})
    file2=\$(find ${fastq_input_dir}/${pid} -type f -name ${read2})
    if [[ -z \${file1} ]]; then
      echo "Warning: Cannot locate fastq_1 file supplied dir: ${fastq_input_dir}/${pid}/${read1}"
      exit 2
    fi
    if [[ -z \${file2} ]]; then
    echo "Warning: Cannot locate fastq_1 file supplied dir: ${fastq_input_dir}/${pid}/${read2}"
      exit 2
    fi
    """
  else if ( !params.paired_global )
    """
    file1=\$(find ${fastq_input_dir}/${pid} -type f -name ${read1})
    if [[ -z \${file1} ]]; then
      echo "Warning: Cannot locate fastq_1 file supplied dir: ${fastq_input_dir}/${pid}/${read1}"
      exit 2
    fi
    """
  else:
     """
      echo "run_check_fastq skipped"
    """
}


/* ===============================================================
  *      FASTQC
  =============================================================== */

process fastqc {
  tag  { params.run_fastqc  ? "${pid}__${sid}" : "blank_run"  }
  cpus { params.run_fastqc  ? params.cpu_standard : params.cpu_min  }
  memory { params.run_fastqc  ? params.mem_standard : params.mem_min  }

  input:
  val x from checkfiles_fastq_complete_ch.collect()
  set sid, pid, read1, read2 from fastqc_ch  

  output:
  val "x" into fastqc_complete_ch
  set sid, pid, read1, read2 into fastqscreen_ch

  script:
  if ( params.paired_global && params.run_fastqc)
    """
    mkdir -p ${fastqcdir}
    mkdir -p ${fastqcdir}/${pid}

    echo "running fastqc in paired reads mode"
    fastqc ${output_dir}/${pid}/${read1} ${output_dir}/${pid}/${read2}  --outdir ${fastqcdir}
    """
  else if ( !params.paired_global && params.run_fastqc)
    """
    mkdir -p ${fastqcdir}
    echo "running fastqc in non paired reads mode "
    fastqc ${output_dir}/${pid}/${read1}  --outdir ${fastqcdir}/${pid}
    """
  else
    """
    echo "run_fastqc skipped"
    """
}




/* ===============================================================
  *      FASTQSCREEN (subset 500k)
  =============================================================== */

process fastqscreen {

    tag  { params.run_fastqscreen  ? "${pid}__${sid}" : "blank_run"  }
    cpus { params.run_fastqscreen  ? params.cpu_standard : params.cpu_min  }
    memory { params.run_fastqscreen  ?  params.mem_standard : params.mem_min  }


    input:
    val x from fastqc_complete_ch.collect()
    set sid, read1, read2, species from fastqscreen_ch //

    output:
    val "x" into fastqscreen_complete_ch

    script:
    if ( params.paired_global ){
        fqsfiles = "${output_dir}/${pid}/${read1} ${output_dir}/${pid}/${read2}" }
    else{
        fqsfiles = "${output_dir}/${pid}/${read1}" }

    if ( params.run_fastqscreen)
      """
      mkdir -p ${fastqscreendir}
      mkdir -p ${fastqscreendir}/${pid}

      fastq_screen \\
          --conf ${params.fastqscreen_config} \\
          --subset 500000 \\
          --outdir ${fastqscreendir}/${pid} \\
          ${fqsfiles}
      """
    else
      """
      echo "run_fastqscreen skipped"
      """
}

/* ===============================================================
  *      multiqc 
  =============================================================== */

// multiqc -- CTG specific multiqc (for entire runfolder)
// Note that multiqc is also copied to the CTG interop folder (multiqcreport=${ctg_qc_root}/multiqc_ctg_interop_${runfolder}) that is synced to QC app
process multiqc {
  tag "${runfolder}"
  cpus params.cpu_standard
  memory params.mem_standard

  input:
  //val x from bcl2fastq_complete.collect()
  val x from fastqscreen_complete_ch.collect()

  output:
  val "x" into multiqc_complete_ch

  script:
  if ( params.run_multiqc )
    """
    ## use -f flag to overwrite if multiqc is already present from failed run.
    ## run multiqc on both runfolder (runfolder_path) and bcl2fastq demux outputdir (output_dir)
    
    cd ${output_dir}
    mkdir -p ${multiqcdir}
    multiqc -n ${multiqcdir}_${runfolder} \\
      --interactive \\
      -f ${runfolder_path} ${output_dir}

    cp -r ${multiqcdir}/multiqc_${runfolder}_data ${ctg_qc_root}/multiqc_ctg_interop_${runfolder}_data
    cp ${multiqcdir}/multiqc_${runfolder}.html ${ctg_qc_root}/multiqc_ctg_interop_${runfolder}.html

    """
  else
    """
    echo "run_multiqc skipped"
    """
}



// finalize
// add to cronlog
// add samplesheet to separate dir
process finalize_pipeline {

  tag  { params.run_finalize_pipeline  ? "${runfolder}" : "blank_run"  }
  memory params.mem_min
  cpus params.cpu_min

  input:
  val x from  multiqc_complete_ch.collect()

  output:
  val "x" into finalize_pipeline_complete_ch

  script:
  if (params.run_finalize_pipeline)
    """
    ## cp samplesheet from nextflow rundir to output dir (demux dir)
    cd ${output_dir}
    mkdir -p samplesheets
    cp ${samplesheet} ./samplesheets/ 

    ## Write cronlog
    touch ${runfolder_path}/ctg.demux.${runfolder}.done ## NOTE! change if allow multiple demux in one runfolder
    cronlog_all="/projects/fs1/shared/ctg-cron/ctg-cron.log"
    cronlog="/projects/fs1/shared/ctg-cron/ctg-pipe-cron/logs/demux/demux.${runfolder}.${samplesheet}.log"
    echo "\$(date): ${runfolder}: DONE: demux (${runfolder})" >> \${cronlog_all}
    echo "\$(date): ${runfolder}: DONE: demux (${runfolder})" >> \${cronlog}


    ## Chmod all dirs
    find ${output_dir} -user $USER -exec chmod g+rw {} +
    find ${ctg_qc_dir} -user $USER -exec chmod g+rw {} +
    """
  else
    """
    echo "skipping run_finalize_pipeline"
    """
}
