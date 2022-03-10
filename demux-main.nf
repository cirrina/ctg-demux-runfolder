
/* ===============================================================
  *      PARAMS FROM CONFIGS
  =============================================================== */

//  re-assign some params from nextflow.configs
// ----------------------------------------------------
//  project and run folders
runfolder           =  params.runFolder    //
work_dir            =  params.nextflow_workir
samplesheet         =  params.samplesheet           // name of simple sample sheet used for pipeline. Must includes file paths to fastq and bamsm, as well as species etc.
output_dir        =  params.output_dir
multiqcreport          =  params.cmultiqcreport


/* ===============================================================
  *       create output and logdirs
  =============================================================== */
// log file for nextflow .onComplete
logfile   =  file( work_dir + '/' + 'log.nextflow.complete' )


/* ===============================================================
  *       CHECKS FILES AND PARAMS
  =============================================================== */

//  Check params
if (runfolder     == '') {exit 1, "You must define a project_id in the nextflow.config"}
if (samplesheet   == '') {exit 1, "You must define a sample sheet path in the nextflow.config"}

// Check if files and directories exist
checkPathParamList = [
  work_dir,
  samplesheet
]
for (param in checkPathParamList) {
    if (param) {
	     file(param, checkIfExists: true)
    }
}
