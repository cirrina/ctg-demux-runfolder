# ctg-demux-runfolder


## Fifty shades of demux

bcl2fastq or mkfastq (cellranger)




### seqonly

### sc-rna-10x
10x chromium sc-RNA data with cellranger

Sample_ID
index
Sample_Project
Sample_Species
nuclei
force
agg
email
deliver

Indexes are suppied as "index" (not same as Index?)
SI-GA-D9
Must use index ID (10x ID) if dual index. For single index, the index sequence works too.
 "Usage: sc-rna-10x [ -v CTG-PIPELINE-VERSION ] [ -i META_ID ] [ -s SAMPLESHEET ] [ -a INDEX-TYPE ] [ -b BCL2FASTQ-ARG ] [ -r RESUME ] [ -c CUSTOM-GENOME ] [ -d DEMUX-OFF ] [ -h HELP ] "  1>&2
 echo "INDEX-TYPE    -a : Set -a if single index uses. (Default: dual) "  
if index == 'dual':
Default is dual.  !!! WHEN would index type be single?

New Sheet
**indexType: Dual/Single**
nuclei/force/agg



### sc-atac-10x
Sample_ID
index
Sample_Project
Sample_Species

Cellranger version: cellranger atac v2.0.0, 
Demultiplexing (cellranger mkfastq):
**echo "INDEX-TYPE    -a : Set -a if single index uses. (Default: dual) "**


### sc-mkfastq-10x
Sample_ID 	index 	Sample_Project
Si1 	SI-GA-D9 	proj_2021_012
Si2 	SI-GA-H9 	proj_2021_012
Sample1 	SI-GA-C9 	proj_2021_013
Sample2 	SI-GA-C9 	proj_2021_013


### sc-cite-seq-10x
Sample_ID 	index 	Sample_Species 	Sample_Project 	Sample_Lib 	Sample_Pair
Sr1 	SI-GA-D9 	human 	2022_022 	rna 	1
Sr2 	SI-GA-H9 	mouse 	2022_022 	rna 	2
Sadt1 	SI-GA-C9 	human 	2022_022 	adt 	1
Sadt2 	SI-GA-C9 	mouse 	2022_022 	adt 	2

[Header]
metaid,2021_067_citeseqTest
antibodies,"ADT_A0574,ADT_A0052,ADT_A0394,ADT_A0161,ADT_A0063,ADT_A0576,ADT_A0054,ADT_A0048"
email,per.a@med.lu.se
autodeliver,y

[Data]
Lane,Sample_ID,index,Sample_Species,Sample_Project,Sample_Lib,Sample_Pair
,EFS_21_022,SI-TT-D5,human,2021_067,rna,1
,con_21_023,SI-TT-E5,human,2021_067,rna,2
,EFS_ADT,ACAGTG,human,2021_067,adt,1
,con_ADT,TGACCA,human,2021_067,adt,2

Sample_Lib
Sample_Pair

??? Sample_Lib : 'rna'/'adt'. Specify whether sample is RNA or ADT library. Note - even if it is and HTO experiment, use adt for HTO.

RNA and ADT/HTO libraries must often have different indexing. It is handled by the pipeline by:

    It looks up the length of adt index, and setting the --use-bases-mask accordingly. If adt index is found to be 6 bases, it will set --use-bases-mask=Y28n*,I6n*,N10,Y90n* during mkfastq_adt.
    By default, it will assume that RNA sample indices are dual, and ADT indices are single. It will thus set --filter-single-index during mkfastq_adt, and --filter-dual-index during mkfastq_rna.



### sc-cellplex-10x
10x multiplex data. GEX + CellPlex on same flowcell

[Header]
metaid,2022_222
email,per.a@med.lu.se
autodeliver,y
[Data]
Lane,Sample_ID,index,Sample_Project,Sample_Species,Sample_Lib,Sample_Pair,Sample,CMO
,CellPlex1,SI-TT-B4,2021_test_Julia_Cellplex_run220221_test,human,gex,1,CellP1,CMO301|CMO302
,CellPlex1_CP,SI-NN-A1,2021_test_Julia_Cellplex_run220221_test,human,cp,1,CellP1
,CellPlex3,SI-TT-B6,2021_test_Julia_Cellplex_run220221_test,human,gex,3,CellP3,CMO303|CMO304
,CellPlex3_CP,SI-NN-D1,2021_test_Julia_Cellplex_run220221_test,human,cp,3,CellP3

Sample_Lib:   'gex'/'cp'. Specify whether sample is RNA (gex) or CellPlex (cp) library.
Sample_Pair :
Sample : ??? Difference from Sample_Pair
CMO : 
cmotype :  multi or single.


