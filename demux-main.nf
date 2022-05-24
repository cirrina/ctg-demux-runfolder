
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
multiqcreport       =  params.multiqcreport

ctg_qc_dir          = "/projects/fs1/shared/ctg-qc/interop/"

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



// bcl2fastq
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


process multiqc {
  tag "${runfolder}"
  cpus params.cpu_standard
  memory params.mem_standard

  input:
  val x from bcl2fastq_complete.collect()

  output:
  val "x" into multiqc_complete_ch

  script:
  if ( params.run_multiqc )
    """
    ## use -f flag to overwrite if multiqc is already present from failed run.
    ## run multiqc on both runfolder and bcl2fastq outputdir
    cd ${output_dir}
    multiqc -n ${multiqcreport} \\
      --interactive \\
      -f ${runfolder_path} ${output_dir}

    """
  else
    """
    echo "run_multiqc skipped"
    """
}



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
