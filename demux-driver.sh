#!/bin/sh

################################################
##  == ** ==  ctg-demux-runfolder  == ** ==
################################################
##           (automated) demux
##        nexflow - blc2fastq & MultiQC
##      runfolder based (not project based)
################################################

##  Input argument:
##    CTG_SampleSheet.demux.*.csv
##    ctg style samplesheet with defined structure - triggers demux

##  Output:
##     bcl2fastq FASTQ, /projects/fs1/shared/demux-runfolder/<runfolder>
##     multiQC report, /projects/fs1/shared/ctg-qc/interop/.. <runfolder> ..

##  Requirements:
##    1. The script must be initiated in the Illumina Runfolder ment for demux
##    2. Samplesheet [Header] 'RunFolder' must match execution  dir
##    3. Samplesheet [Header] 'PipelineName' == 'ctg-demux-runfolder'
##    4. Samplesheet [Header] 'PipelineVersion': mut be valid and a subdirectry of the pipeline dir
##    5. The bcl2fastq fastq output folder must not exist (move or delete old runs).

## this sctipt is a continuation of the ctg-demux2 batch script but with nextflow functionality

################################################
##  == 1 ==  Define Params
################################################
scripts_root="/projects/fs1/shared/ctg-pipelines"
ctg_qc_root='/projects/fs1/shared/ctg-qc/interop' ## should be added pipelineProfile/ProjectID
output_root='/projects/fs1/shared/demux-runfolder'
## Script & config names
nf_script="demux-main.nf"

# Get current directory (MUST BE EXECUTED FROM RUN FOLDER
exec_dir=$(pwd) ## full path where script is executed
execdir_base=${PWD##*/} ##  dirname only - should match runfolder supplied in samplesheet


################################################
##  == 2 ==  Read & Check input args (samplesheet name)
################################################
sheet=$1
if [ -z $sheet ]
then
  echo "> WARNING: No samplesheet specified"
  exit 1
else
  samplesheet=${exec_dir}/${sheet} ## samplesheet - full path of sheet
  basesheet=$(echo $samplesheet | sed 's/.csv//g') ## basesheet - samplesheet name , no path
  if [ ! -f ${sheet} ]; then
      echo ""; echo ""; echo "Error:"
      echo "SampleSheet not found (in current dir)"
      exit 1
  fi
fi

################################################
##  == 3 ==  Read SampleSheet Params
################################################
## Check exec_dir is same as `RunFolder` in samplesheet [Header]
## store runFolder param
runfolder=$(awk -F, '$1 == "RunFolder"' ${samplesheet} | awk -F, '{print $2}')
if [[ ! ${runfolder} ==  ${execdir_base}]]; then
  echo " Warning: 'RunFolder' is not properly supplied in samplesheet [Header]";
  echo " Must be same as execution dir."; echo""; echo ""
  exit 1
fi

## Read PipelineName, PipelineProfile and PipelineVersion
pipelineName=$(awk -F, '$1 == "PipelineName"' ${samplesheet} | awk -F, '{print $2}')
pipelineVersion=$(awk -F, '$1 == "PipelineVersion"' ${samplesheet} | awk -F, '{print $2}')
pipelineProfile=$(awk -F, '$1 == "PipelineProfile"' ${samplesheet} | awk -F, '{print $2}') ## not implemented - could be demux with different index lengths
bcl2fastqarg=$(awk -F, '$1 == "bcl2fastqArg"' ${samplesheet} | awk -F, '{print $2}') ## argument line for bcl2fastq

# Check pipelineName (expect ctg-demux-runfolder pipeline)
if [ ! "$pipelineName" == "ctg-demux-runfolder" ]; then
  echo ""; echo "";
  echo " Warning: 'PiepelineName' not set. Expecting 'ctg-demux-runfolder' " ;
  echo ""
  exit 1

# Generate pipeline path (scritps_root + pipelineName + pipelineVersion)
# copy scripts to local workdir within demux output folder (below)
scripts_dir="${scripts_root}/${pipelineName}/${pipelineVersion}"

if [[ ! -d ${scripts_dir} ]]; then
  echo ""; echo "";
  echo " Warning: scripts_dir does not exist: ${scripts_dir} "; echo ""
  echo " Make sure PipelineName and PipelineVersion are correctly supplied in SampleSheet"; echo " AND that they match a directory whtin the scripts_root folder: ${scripts_root}."
  exit 1
fi


################################################
##  == 4 ==  Create Output dir & NextFlow workdir
################################################
outputdir=${output_root}/${runfolder} ## the outputdir is the base for script/demux output. will be used as -o in bcl2fastq
workdir_nf=${outputdir}/nextflow-workdir
multiqcreport=${ctg_qc_root}/multiqc_ctg_interop_${runfolder}

## nextflow workfiles (nf-workdir), containing pipeline scripts are copied to this folder
## The multiqc is set to replace existing multiqc files (generated in ctg-qc/interop by the ctg-interop cron)
##         The current multiQC will have added demux stats
## future: if variable idexes lengths in demux, there must be a dynamic of seettig demux output dirs wihtin the outputdir
##         perhaps using PipelineProfile to define a mode that can use mutiple subfolders within the outputdir as output

if [[  -d ${outputdir} ]] ; then
  echo ""; echo ""; echo "Error:"
  echo "outputdir already exist: ${outputdir} "; echo ""
  exit 1
fi
mkdir -p ${outputdir}

cp -r ${scripts_dir}/* ${workdir_nf} # copy all scripts to workfolder. Will overwrite netflow.config
chmod -R 775 ${workdir_nf}
cp ${samplesheet} ${workdir_nf} # Copy samplesheet to project workfolder
cd ${workdir_nf}



################################################
##  == 5 ==  Generate NextFlow Config
################################################
## - nextflow.config.params.${runfolder}
nf_config_project="${workdir_nf}/nextflow.config.params.${runfolder}"

echo ""
echo " ... Writing nextflow parameters to project-specific config: ${nf_config_project}"

## Write nextflow params to file
echo ""  > ${nf_config_project}
echo "//  nextflow configuration file"           >> ${nf_config_project}
echo "//  ctg-demux-runfolder:  ${runfolder}"    >> ${nf_config_project}
echo "//"                                        >> ${nf_config_project}
echo ""                                          >> ${nf_config_project}
echo " params {"                                 >> ${nf_config_project}
echo ""                                          >> ${nf_config_project}
echo "  pipelineName       =  '${PipelineName}'       " >> ${nf_config_project}
echo "  pipelineProfile    =  '${PipelineProfile}'                          " >> ${nf_config_project}
echo "  pipelineVersion    =  '${PipelineVersion}'                          " >> ${nf_config_project}
echo "  pipeline_scrips_dir  =  '${scripts_dir}'            " >> ${nf_config_project}
echo ""                                         >> ${nf_config_project}
echo "  runFolder          =   ${runfolder}        " >> ${nf_config_project}
echo "  runfolder_path     =  '${exec_dir}'        " >> ${nf_config_project}
echo "  nextflow_workir    =  '${workdir_nf}'      " >> ${nf_config_project}
echo "  output_dir         =  '${outputdir}'       " >> ${nf_config_project}
echo "  samplesheet        =  '${samplesheet}'     " >> ${nf_config_project}
echo "  multiqcreport      =  '${mqcreport}'       " >> ${nf_config_project}
echo ""                                            >> ${nf_config_project}
echo "//  process arguments"           >> ${nf_config_project}
echo "  bcl2fastqarg      =  '${bcl2fastqarg}'     " >> ${nf_config_project}
echo " }"                                          >> ${nf_config_project}
echo ""                                            >> ${nf_config_project}


################################################
##  == 6 ==  Execute the main NextFlow script
################################################
cd ${project_dir}

echo ""; echo "";
echo " Initiating nextflow pipeline"
echo " ... pipelineName      : ${pipelineName}";
echo " ... pipelineVersion   : ${pipelineVersion}";
echo " ... pipelineProfile   : ${pipelineProfile}";
echo " ... runFolder         : ${runfolder}";
echo " ... nextflow_workir   : ${workdir_nf}";
echo " ... fastq output      : ${outputdir}";
echo ""; echo "";

## intiate the nextflow command. include project specific config & profile -p
cd ${workdir_nf}
nohup nextflow run ${nf_script} -c ${nf_config_project} > log.nextflow.progress &

echo ""
echo "  Running :   nextflow run ${nf_script} -c ${nf_config_project}"
echo "";
echo "  ########################## "
echo "      S U B M I T T E D "
echo "  ########################## "
echo "  Logfile :  ${workdir_nf}/log.nextflow.progress "
echo ""