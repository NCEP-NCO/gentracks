#!/bin/sh

# USE_OPER_VITALS=NO
export USE_OPER_VITALS=YES
# USE_OPER_VITALS=INIT_ONLY

#export PS4=' + genesis_tracker_poe.sh line $LINENO: '
export PS4='$SECONDS + genesis_tracker_poe.sh line $LINENO: '

set +x
##############################################################################
echo " "
echo "------------------------------------------------"
echo "xxxx - Track vortices in model GRIB output"
echo "------------------------------------------------"
echo "History: Mar 1998 - Marchok - First implementation of this new script."
echo "         Apr 1999 - Marchok - Modified to allow radii output file and"
echo "                              to allow reading of 4-digit years from"
echo "                              TC vitals file."
echo "         Oct 2000 - Marchok - Fixed bugs: (1) copygb target grid scanning"
echo "                              mode flag had an incorrect value of 64"
echo "                              (this prevented Eta, NGM and ECMWF from"
echo "                              being processed correctly);" 
echo "                              Set it to 0."
echo "                              (2) ECMWF option was using the incorrect"
echo "                              input date (today's date instead of "
echo "                              yesterday's)."
echo "         Jan 2001 - Marchok - Hours now listed in script for each model"
echo "                              and passed into program.  Script included"
echo "                              to process GFDL & Ensemble data.  Call to"
echo "                              DBN included to pass data to OSO and the"
echo "                              Navy.  Forecast length extended to 180"
echo "                              hours for GFS."
echo "         Nov 2004 - Burroughs - Modified scripts to make extratropical"
echo "                              storm tracker operational.  Added hooks in"
echo "                              post processing jobs for various models."
echo "         May 2006 - Burroughs - Modified scripts to accommodate the new"
echo "                              gefs file structure.  Cut the number of"
echo "                              files used by going from 6-h frequency to"
echo "                              12-h frequency from 120 - 180-h."
echo "       May 2007 - Guang P Lou - Expanded scripts to include the following"
echo "                    changes: "
echo "                  1. Short range ensembles(sref) expanded to 21 from 14;  "
echo "                     model forecast length increased from 63hrs to 87hrs      "
echo "                  2. Canadian model is added                                 "
echo "                  3. Canadian ensemble with 17 perturbation runs are initiated  "
echo "                  4. ECMWF model frequency increased from 1 (00z) to 2 (00z,12z); "
echo "                     model length extended from 180hrs to 240hrs    "
echo "                  5. ECMWF ensemble runs with 50 components are added; "
echo "                     ECMWF ensemble runs once a day only at 12z to 240hrs "
echo "                  6. Region domain boundaries have changed for ecml and wpcg"
echo "                     and domain cptg has been removed                         "
echo "                  7. Tracks are sorted to order and to files according "
echo "                     to region and model and saved for future usage "
echo "                  8. All cyclones lived shorter than 24hrs are removed "
echo "                  9. Tracks are also grouped for graphics in post processing "
echo "                 10. The cyclone center pressure gradient is relaxed to 1hPa from 2hPa  "
echo "  "
echo "       Sept. 2008 - Guang Ping Lou - Expanded scripts to include the following changes: "
echo "                  1. It uses Poe scheme to increase nodes and tasks so that "
echo "                     ensemble runs are assigned as many tasks(CPU) as ensemble members "
echo "                     It reduces wall clock requirements greatly. "
echo "                     The real wall clock should be within 30 minutes for any ensemble. "
echo "                  2. A global version replaces the previous regional tracker. "
echo "                     Now the tracker search domain includes -90~90, 0~360. "
echo "                  3. The atcf text output files include (glbl) in place of "
echo "                     regional ecml, altg, eptg, wptg  "
echo "                  4. The data is output with names (storms.$model.atcfunix.glbl.$yyyy) "
echo "                  5. A new file is created with name (trak.$model.atcf_gen.glbl.$yyyy) " 
echo "                     which has a new Storm ID to include initial date, lead-time in forecast and "
echo "                     lat/lon position where storm was first identified. "
echo "                  6. New text output format includes: "
echo "                     Positions for the 3 diagnostics from Bob Hart's cyclone phase space "
echo "                     (the CPS values are only calculated for lead times > hour 0 or > the "
echo "                     first hour at which the storm was found, since it's critical to have a "
echo "                     good fix on the direction of storm motion). "
echo "                     Mean & max values of relative vorticity near the storm at 850 & 700 "
echo "                     Direction of model storm motion, Translation speed of model storm, "
echo "                     The pressure of the last closed isobar and the radius "
echo "                     of that closed isobar, but found the algorithm to be too unreliable. "
echo "                     Nonetheless, the values are output   "
echo "                  7. A CXML script is added to generate a cyclone output format "
echo "                     that confines with the international format "
echo " "
echo "                    In the event of a crash, you can contact Guang Ping Lou "
echo "                    at NCEP/EMC at (301) 763-8000x7252 or "
echo "                    guang.ping.lou@noaa.gov or Tim Marchok at "
echo "                    tpm@gfdl.gov"
echo "                    8/20/13 - Magee - change ngps to nvgm."
echo " "
echo "Current time is: `date`"
echo " "
##############################################################################
set -x

##############################################################################
#
#    FLOW OF CONTROL
#
# 1. Define data directories and file names for the input model 
# 3. Define extratropical and tropical regions
# 3. Process input starting date/cycle information
# 4. Update TC Vitals file and select storms to be processed
# 5. Cut apart input GRIB files to select only the needed parms and hours
# 6. Execute the tracker
# 7. Copy the output track files to various locations
#
##############################################################################

########################################
msg="has begun for ${cmodel} at ${cyc}z"
postmsg "$jlogfile" "$msg"
########################################

# This script runs the hurricane tracker using operational GRIB model output.  
# This script makes sure that the data files exist, it then pulls all of the 
# needed data records out of the various GRIB forecast files and puts them 
# into one, consolidated GRIB file, and then runs a program that reads the TC 
# Vitals records for the input day and updates the TC Vitals (if necessary).
# It then runs genesis_gettrk, which actually does the tracking.
# 
# Environmental variable inputs needed for this script:
#  PDY      -- The date for data being processed, in YYYYMMDD format
#  CYL      -- The numbers for the cycle for data being processed (00, 06, 09, 
#              12, 18, 21)
#  cmodel   -- Model being processed (gfs, ukmet, ecmwf, nam, nvgm, gdas, gfdl, 
#              gefs (ncep GFS ensemble), sref (nam ensemble), cens (canadian 
#              ensemble; to be added), north american ensemble - to be added)
#  envir    -- 'prod', 'para', or 'test'
#  SENDCOM  -- 'YES' or 'NO'
#  stormenv -- This is only needed by the tracker run for the GFDL model.
#              'stormenv' contains the name/id that is used in the input
#              grib file names.
#  pert     -- This is only needed by the tracker run for the NCEP ensembles.
#              'pert' contains the ensemble member id (e.g., n2, p4, etc.)
#              which is used as part of the grib file names.
#  loopnum  -- This is used to determine which region is used by the program;
#              region types (regtype) include:
#                 ecml = Extratropical cyclogenesis, mid-latitude Atlantic and
#                        Pacific; loopnum = 1
#                 altg = Atlantic Basin, tropical cyclogenesis; loopnum = 2
#                 eptg = Eastern Pacific Basin, tropical cyclogenesis;
#                        loopnum = 3
#                 wptg = Western Pacific Basin, tropical cyclogenesis; 
#                        loopnum = 4
#
# For testing script interactively in non-production set following vars:
#     gfsvitdir  - Directory for GFS Error Checked Vitals
#     namvitdir  - Directory for Eta Error Checked Vitals
#     gltrkdir   - Directory for output tracks
#     homesyndir - Directory with syndir scripts/exec/fix 
#     archsyndir - Directory with syndir scripts/exec/fix 
#
#-----------------------------------------------------------------------------
# This job runs the tracker for an input cmodel, loopnum, PDY, and CYL
#-----------------------------------------------------------------------------

set +x
echo " "
echo "Time at beginning of `basename $0` is `date`"
set -x

qid=$$

#--------------------------------------------------
#   Get input information
#--------------------------------------------------

export PDY=${PDY:-$1}
export CYL=${CYL:-$2}
export CYCLE=t${CYL}z
export cmodel=${cmodel:-$3}
export loopnum=${reg:-$4}
export init_flag=$5
#JY export COMIN=${COMIN:-$cmodel}
#JY export COMOUT=${COMOUT:-${COMIN}/track}
export SENDCOM=${SENDCOM:-YES}
#SH export PARAFLAG=${PARAFLAG:-YES}
export PARAFLAG=${PARAFLAG:-NO}
export PHASEFLAG=y
export PHASE_SCHEME=cps

export scc=`echo ${PDY} | cut -c1-2`
export syy=`echo ${PDY} | cut -c3-4`
export smm=`echo ${PDY} | cut -c5-6`
export sdd=`echo ${PDY} | cut -c7-8`
export shh=${CYL}
export symd=`echo ${PDY} | cut -c3-8`
export syyyy=`echo ${PDY} | cut -c1-4`
export CENT=${scc}


if [ ! -d ${DATA} ];   then mkdir -p ${DATA}; fi

echo "shell is  " $shell

cd $DATA
# JY export COMGLTRK=${COMGLTRK:-${COMROOT}/gentracks/prod/gentracks}
        export savedir=${savedir:-$COMGLTRK/${syyyy}}
if [ ! -d ${savedir} ];   then mkdir -p ${savedir}; fi

#/nwprod/util/ush/setup.sh
. prep_step

if [ ${#PDY} -eq 0 -o ${#CYL} -eq 0 -o ${#cmodel} -eq 0 ]
then
   set +x
   echo " "
   echo "Something wrong with input data.  One or more input variables has "
   echo "length 0. PDY = ${PDY}; CYL = ${CYL}; cmodel = ${cmodel};"
   echo "EXITING.........."
   set -x
   err_exit " FAILED ${jobid} -- BAD INPUTS AT LINE $LINENO IN TRACKER SCRIPT - ABNORMAL EXIT"
else
  set +x
  echo " "
  echo " #-----------------------------------------------------------------#"
  echo " At beginning of tracker script, the following imported variables "
  echo " are defined: "
  echo "   PDY ................................... $PDY"
  echo "   CYL ................................... $CYL"
  echo "   CYCLE ................................. $CYCLE"
  echo "   cmodel ................................ $cmodel"
  echo "   loopnum................................ $loopnum"
  echo "   jobid ................................. $jobid"
  echo "   envir ................................. $envir"
  echo "   SENDCOM ............................... $SENDCOM"
  echo " "
  set -x
fi

export gribver=${gribver:-2}
  if [ ${cmodel} = 'eens' -o ${cmodel} = 'ecmwf' -o ${cmodel} = 'ukmet' ]; then
   export gribver=1
  fi
if [ ${cmodel} = 'gefs' ]; then
# Global ensemble
APRUN="mpiexec --cpu-bind core --configfile" 
  pertstring=' p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20 c00 p21 p22 p23 p24 p25 p26 p27 p28 p29 p30'
elif [ ${cmodel} = 'sref' ]; then
# Short range ensemble
   if [ ${gribver} = 1 ]; then
APRUN="mpiexec --cpu-bind core --configfile" 
     pertstring=' sac1 san1 sap1 san2 sap2 san3 sap3 snc1 snn1 snp1 snn2 snp2 snn3 snp3 sbc1 sbn1 sbp1 sbn2 sbp2 sbn3 sbp3'
# new members replace old above Jan 2015:
   else
APRUN="mpiexec --cpu-bind core --configfile" 
     pertstring=' sac1 san1 san2 san3 san4 san5 san6 sap1 sap2 sap3 sap4 sap5 sap6 sbc1 sbn1 sbn2 sbn3 sbn4 sbn5 sbn6 sbp1 sbp2 sbp3 sbp4 sbp5 sbp6'
   fi
elif [ ${cmodel} = 'eens' ]; then
APRUN="mpiexec --cpu-bind core --configfile" 
# ECMWF ensemble
  pertstring=' p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20 p21 p22 p23 p24 p25 n01 n02 n03 n04 n05 n06 n07 n08 n09 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20 n21 n22 n23 n24 n25'
elif [ ${cmodel} = 'cens' ]; then
APRUN="mpiexec --cpu-bind core --configfile" 
# Canadian ensemble
  pertstring=' c00 p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20'
elif [ ${cmodel} = 'fens' ]; then
APRUN="mpiexec --cpu-bind core --configfile" 
  pertstring=' p00 p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20'
else 
APRUN="mpiexec --cpu-bind core --configfile" 
  pertstring=' xxxx'
fi

set +x
echo " "
echo " "
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo " PROCESSING LOOP NUMBER $loopnum IN tracker.sh"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++"
## since the new version covers half hemisphere, loopnum is no longer needed.
echo " "
echo " "
set -x

if [ ${loopnum} -eq 1 ]; then
# glbl: Global tropical cyclogenesis
   export trkrtype=tcgen
   export regtype=tggb
else
# glbl: Global cyclogenesis
   export trkrtype=midlat
   export regtype=glbl
fi
export trkrebd=360.0
export trkrwbd=0.0
export trkrnbd=89.0
export trkrsbd=-89.0

if [ $cmodel = 'gfs' ]; then
   bmodel=gfso
elif [ $cmodel = 'ukmet' ]; then
   bmodel=ukx
elif [ $cmodel = 'ecmwf' ]; then
   bmodel=emx
elif [ $cmodel = 'nvgm' ]; then
   bmodel=ngx
else
   bmodel=$cmodel
fi

export TRKDATA=${DATA}/${bmodel}
if [ ! -d ${TRKDATA} ]; then mkdir -p ${TRKDATA}; fi

cp $USHtrkr/genesis_gettrk_poe.sh .
rm -rf poe_ens

for pert in ${pertstring}
do
  # Create the poe script for each member
  echo " ./genesis_gettrk_poe.sh $pert" >>poe_ens
done

mv poe_ens cmdfile
chmod +x cmdfile
cat cmdfile

#SH ##### Testing with more MP setting for debugging purpose #####
#  export MP_LABELIO=YES
#  export MP_INFOLEVEL=3
##SH ##############################################################

# Execute the poe
$APRUN cmdfile

if [ "${RUN}" = "fens" ]; then
if [ -e ${DATA}/missing_fnmoc_files ]; then
  echo "${DATA}/missing_fnmoc_files exists, exiting"
  exit
else
  echo "no ${DATA}/missing_fnmoc_files exists, continue"
fi
fi

if [ "${RUN}" = "navgem" ]; then
if [ -e ${DATA}/missing_navgem_files ]; then
  echo "${DATA}/missing_navgem_files exists, exiting"
  exit
else
  echo "no ${DATA}/missing_navgem_files exists, continue"
fi
fi

#export err=$?; err_chk

#wait

case ${cmodel} in
  gefs) aa=a;;
  eens) aa=e;;
  cens) aa=c;;
  fens) aa=f;;
     *) aa="";;
esac

if [ ${SENDCOM} = 'YES' ]; then
 if [ $regtype = "glbl" ] ; then
  if [ ${bmodel} = 'gefs' -o ${bmodel} = 'eens' -o ${bmodel} = 'sref' -o ${bmodel} = 'cens' ]; then
    for pert in ${pertstring}
     do
      if [ -f ${COMOUT_dailyTRK}/${aa}${pert}.t${CYL}z.cyclone.trackatcfunix.${regtype} ]; then
      cat ${COMOUT_dailyTRK}/${aa}${pert}.t${CYL}z.cyclone.trackatcfunix.${regtype} >> ${COMOUT_dailyTRK}/cyclone_${PDY}${CYL}.ens
      fi
     done
   else
      cat ${COMOUT_dailyTRK}/${bmodel}.t${CYL}z.cyclone.trackatcfunix.${regtype} >> ${COMOUT_dailyTRK}/cyclone_${PDY}${CYL}.ens
  fi
   if [ $SENDDBN = "YES" ] ; then
   $DBNROOT/bin/dbn_alert MODEL OMBATCF $job ${COMOUT_dailyTRK}/cyclone_${PDY}${CYL}.ens
   fi
 fi

fi

if [ ${cmodel} = 'gefs' -o ${cmodel} = 'gfs' -o ${cmodel} = 'cens' ]; then
cd ${DATA}
perl $USHtrkr/atcf2xml.prod.pl --date ${PDY}${CYL} --model ${cmodel} --basin ${regtype}
cp kwbc_${PDY}${CYL}0000_*.xml ${COMOUT_dailyTRK}
cp kwbc_${PDY}${CYL}0000_*.xml ${COMOUT}
fi

if [ ${loopnum} -ne 1 ]; then
# Now start the verification portion: first do the pairing.
export optrack=$COMOUT/plot
if [ ! -d ${optrack} ]; then mkdir ${optrack}; fi
cd $TRKDATA

wait
rm -rf poe_veri
rm -rf poe_ens
  if [[ ${bmodel} != 'gefs' && ${bmodel} != 'eens' && ${bmodel} != 'sref' && ${bmodel} != 'cens' && ${bmodel} != 'fens' ]]; then
for pert in ${pertstring}
do
   export $pert

   # Create the poe script for each member
##   echo "sh ${USHtrkr}/verify_pair_glbl.sh $PDY$CYL $pert $regtype" >>poe_veri
   sh ${USHtrkr}/verify_pair_glbl.sh $PDY$CYL $pert $regtype

done

wait
cd $TRKDATA
#now do the tropical named storms paring
   sh ${USHtrkr}/verify_pair_tcvit.sh $PDY$CYL $regtype
# Now continue the verification portion: second do the verification.
rm plot_*.out
   sh ${USHtrkr}/verify_ver.sh $PDY$CYL ${bmodel} $regtype

cd $TRKDATA
# after the verification, do the gathering
  if [ ${cmodel} = 'sref' ]; then
     eymdhs=${PDY}${CYL}
  case ${CYL} in
    03) eymdh=${PDY}00;;
    09) eymdh=${PDY}06;;
    15) eymdh=${PDY}12;;
    21) eymdh=${PDY}18;;
  esac
    else
     eymdh=${PDY}${CYL}
  case ${CYL} in
    00) eymdhs=${PDY}03;;
    06) eymdhs=${PDY}09;;
    12) eymdhs=${PDY}15;;
    18) eymdhs=${PDY}21;;
  esac
  fi

          if (( ${CYL} == 12 | ${CYL} == 0 | ${CYL} == 15 | ${CYL} == 03 )); then
> plot_na_${eymdh}z.out
  for model in gfso ngx ukx cmc emx 
   do
if [ -f ${optrack}/htcard.${model}.na_${eymdh}z.out ]; then
 cat ${optrack}/htcard.${model}.na_${eymdh}z.out >> plot_na_${eymdh}z.out
fi
   done
if [ -f ${optrack}/htcard.nam.al_${eymdh}z.out ]; then
cat ${optrack}/htcard.nam.al_${eymdh}z.out >> plot_na_${eymdh}z.out
fi

sh ${USHtrkr}/tvercut_opr.sh plot_na_${eymdh}z.out
cp plot_na_*z.dat ${optrack}
cp plot_na_*z.ctl ${optrack}
cp plot_na_*z.gr  ${optrack}

if [ ${bmodel} = 'gfso' -o ${bmodel} = 'ngx' -o ${bmodel} = 'emx' \
                -o ${bmodel} = 'ukx' -o ${bmodel} = 'cmc' ]; then
> plot_${eymdh}z.out
  for model in gfso ngx ukx cmc emx
  do
    if [ -f ${optrack}/htcard.${model}.al_${eymdh}z.out ]; then
      cat ${optrack}/htcard.${model}.al_${eymdh}z.out >> plot_${eymdh}z.out
    fi
  done
sh ${USHtrkr}/tvercut_opr.sh plot_${eymdh}z.out
cp plot_*z.dat ${optrack}
cp plot_*z.ctl ${optrack}
cp plot_*z.gr  ${optrack}

fi
fi

#Now do the named tropical storm verification if there is any
ls a*${syyyy}.dat > besttrack
nist=` cat besttrack | wc -l`
if [ ${nist} -ge 1 ]; then 
while read atcfrec
do
stmnm=` echo  "${atcfrec}" | cut -c2-11`
#kist=` cat htcard.${stmnm}.xtr.dat | wc -l`
#if [ ${kist} -ne 0 ]; then 
sh ${USHtrkr}/tvercut_glbl.sh htcard.${stmnm}.out
cp htcard.${stmnm}.dat ${optrack}
cp htcard.${stmnm}.ctl ${optrack}
cp htcard.${stmnm}.out ${optrack}

baschar=` echo "${atcfrec}" | cut -c2-3 | tr "[a-z]" "[A-Z]"` 
stn=` echo "${atcfrec}" | cut -c6-7` 

case ${baschar} in
  AL) BASIN=L; bname="Atlantic Basin";;
  WP) BASIN=W; bname="West Pacific";;
  EP) BASIN=E; bname="East Pacific";;
  CP) BASIN=C; bname="Central Pacific";;
  NA) BASIN=A; bname="Arabian Sea";;
  BB) BASIN=B; bname="Bay of Bengal";;
  SI) BASIN=S; bname="South Indian Ocean";;
  SP) BASIN=P; bname="South Pacific";;
  SC) BASIN=O; bname="South China Sea";;
  EC) BASIN=T; bname="East China Sea";;
  AU) BASIN=U; bname="Australian";;
  *) echo "!!! ERROR: BAD BASIN CHARACTER = --> $baschar <--"; exit 8;;
esac

stmname=` tail -1 ${stn}${BASIN}.${syyyy}.tempvit |cut -c10-18`
hcenter=` head -1 ${stn}${BASIN}.${syyyy}.tempvit |cut -c1-4`

#fi
done <besttrack
fi

# Now plot out all tracks

cd $TRKDATA
    grmodel=${bmodel}
>storms.all.atcfunix.${regtype}.${eymdh}
>fcst_all
>storms.anal_wemx.atcfunix.${regtype}.${eymdh}
>storms.all_wemx.atcfunix.${regtype}.${eymdh}
# gather current day forecast tracks and past 10 day analysis tracks:
  for model in gfso nam ngx ukx cmc emx
   do
if [ -f ${optrack}/trackf_${model}_${eymdh} ]; then
    cat ${optrack}/trackf_${model}_${eymdh} >> storms.all_wemx.atcfunix.${regtype}.${eymdh}
    cat ${optrack}/bml${eymdh}.${model}.* >> storms.anal_wemx.atcfunix.${regtype}.${eymdh}
fi
  done
    cp storms.anal_wemx.atcfunix.${regtype}.${eymdh} storms.anal_all.atcfunix.${regtype}.${eymdh}
    grep -v -i emx storms.all_wemx.atcfunix.${regtype}.${eymdh} >> storms.all.atcfunix.${regtype}.${eymdh}

  if [[ ${bmodel} != 'gefs' && ${bmodel} != 'eens' && ${bmodel} != 'sref' && ${bmodel} != 'cens' ]]; then
   grep -i ${bmodel} storms.anal_wemx.atcfunix.${regtype}.${eymdh} > storms.anal_${bmodel}.atcfunix.${regtype}.${eymdh}
   grep -i  ${bmodel} storms.all_wemx.atcfunix.${regtype}.${eymdh} > storms.${bmodel}.atcfunix.${regtype}.${eymdh}
  fi

## SH  comment out this section of codes because we do not have the paired tracks for ensemble models any more
#  if [ ${bmodel} = 'gefs' ]; then
#    cat ${optrack}/trackf_gfso_${eymdh} > storms.aeperts.atcfunix.${regtype}.${eymdh}
#    cat ${optrack}/bml${eymdh}.gfso.*   > storms.anal_aeperts.atcfunix.${regtype}.${eymdh}
#for pert in ${pertstring} ; do
#    cat ${optrack}/trackf_${aa}${pert}_${eymdh} >> storms.aeperts.atcfunix.${regtype}.${eymdh}
#    cat ${optrack}/bml${eymdh}.${aa}${pert}.*   >> storms.anal_aeperts.atcfunix.${regtype}.${eymdh}
#done
#    grmodel=aeperts
#  fi
#
#  if [ ${bmodel} = 'cens' ]; then
#    cat ${optrack}/trackf_cmc_${eymdh} > storms.ceperts.atcfunix.${regtype}.${eymdh}
#    cat ${optrack}/bml${eymdh}.cmc.*   > storms.anal_ceperts.atcfunix.${regtype}.${eymdh}
#for pert in ${pertstring} ; do
#    cat ${optrack}/trackf_${aa}${pert}_${eymdh} >> storms.ceperts.atcfunix.${regtype}.${eymdh}
#    cat ${optrack}/bml${eymdh}.${aa}${pert}.*   >> storms.anal_ceperts.atcfunix.${regtype}.${eymdh}
#done
#    grmodel=ceperts
#  fi
#
#  if [ ${bmodel} = 'eens' ]; then
#    cat ${optrack}/trackf_emx_${eymdh} > storms.eeperts.atcfunix.${regtype}.${eymdh}
#    cat ${optrack}/bml${eymdh}.emx.*   > storms.anal_eeperts.atcfunix.${regtype}.${eymdh}
#for pert in ${pertstring} ; do
#    cat ${optrack}/trackf_${aa}${pert}_${eymdh} >> storms.eeperts.atcfunix.${regtype}.${eymdh}
#    cat ${optrack}/bml${eymdh}.${aa}${pert}.*   >> storms.anal_eeperts.atcfunix.${regtype}.${eymdh}
#done
#    grmodel=eeperts
#  fi
#
#  if [ ${bmodel} = 'sref' ]; then
#    cat ${optrack}/trackf_nam_${eymdh} > storms.srperts.atcfunix.${regtype}.${eymdhs}
#    cat ${optrack}/bml${eymdh}.nam.*   > storms.anal_srperts.atcfunix.${regtype}.${eymdhs}
#for pert in ${pertstring} ; do
#    cat ${optrack}/trackf_${pert}_${eymdhs} >> storms.srperts.atcfunix.${regtype}.${eymdhs}
#    cat ${optrack}/bml${eymdhs}.${pert}.*   >> storms.anal_eeperts.atcfunix.${regtype}.${eymdhs}
#done
#    grmodel=srperts
#  fi

cp storms.*atcfunix.${regtype}.* ${optrack}
# "if [[ ${bmodel} != 'gefs' &&" ends here
fi
# if(loopnum) ends here
fi

#---------------------------------------------
set +x
echo " "
echo "Time at end of `basename $0` is `date`"
#-------------------------END EXTRKR_NEW.SMS.SH-------------------------
