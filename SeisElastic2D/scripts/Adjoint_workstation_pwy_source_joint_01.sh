#!/bin/bash

# parameters
source ./parameter
velocity_dir=$1
compute_adjoint=$2

# local id (from 0 to $ntasks-1)

iproc=0

# allocate tasks over all sources
# ntasks in parallel and nsrc in total
# take ceiling 
nsrc_per_task_ceiling=$(echo $(echo "$NSRC $ntasks" | awk '{ print $1/$2 }') | \
    awk '{printf("%d\n",$0+=$0<0?0:0.999)}')
ntasks_ceiling=$(echo $(echo "$NSRC $ntasks" | awk '{print $1%$2}'))
# take floor 
nsrc_per_task_floor=$(echo $(echo "$NSRC $ntasks" | awk '{ print int($1/$2) }'))


# allocate nsrc for each task
if [ $iproc -lt $ntasks_ceiling ]; then
    nsrc_this_task=$nsrc_per_task_ceiling
    isource_start=$(echo $(echo "$iproc $nsrc_per_task_ceiling" | awk '{ print $1*$2 }'))
else
    nsrc_this_task=$nsrc_per_task_floor
    isource_start=$(echo $(echo "$iproc $nsrc_per_task_floor \
        $ntasks_ceiling $nsrc_per_task_ceiling" | awk '{ print ($1-$3)*$2+$3*$4 }'))
fi

#isource=1
for ((isource=1; isource<=${NSRC}; isource++));
do 
    # STEP one -- forward simulation
    STARTTIME=$(date +%s)
    data_tag='DATA_syn'
    if $compute_adjoint ; then   
        SAVE_FORWARD=true
    else
       SAVE_FORWARD=false
    fi
    bash $SCRIPTS_DIR/Forward_specfem2D_pwy_source.sh $isource $NPROC_SPECFEM $data_tag $data_list \
         $velocity_dir $SAVE_FORWARD $WORKING_DIR_01 $DISK_DIR_01 $DATA_DIR $job 2>./job_info/error_Forward_simulation_01
    if [ $isource -eq 1 ] && $compute_adjoint ; then
       ENDTIME=$(date +%s)
       Ttaken=$(($ENDTIME - $STARTTIME))
       echo "Forward simulation took $Ttaken seconds"
    fi

    # STEP two -- adjoint source
    # first calculate kernels with attenuation
    VISCOELASTIC=false
    STARTTIME=$(date +%s)
    bash $SCRIPTS_DIR/adjoint_source.sh $isource $NPROC_SPECFEM $compute_adjoint $data_list \
        $measurement_list_01 $misfit_type_list $WORKING_DIR_01 $DISK_DIR_01 $Wscale $wavelet_path $VISCOELASTIC $measurement_attenuation 2>./job_info/error_adj_source

    if [ $isource -eq 1 ] && $compute_adjoint ; then
        ENDTIME=$(date +%s)
        Ttaken=$(($ENDTIME - $STARTTIME))
        echo "adjoint source took $Ttaken seconds"
    fi

    # STEP three -- adjoint simulation?
    STARTTIME=$(date +%s)
    if $compute_adjoint; then
       data_tag='SEM'
       SAVE_FORWARD=false
       bash $SCRIPTS_DIR/Adjoint_${solver}.sh $isource $NPROC_SPECFEM $data_tag \
            $velocity_dir $SAVE_FORWARD $WORKING_DIR_01 $DISK_DIR_01 2>./job_info/error_Adjoint_simulation
    fi
    if [ $isource -eq 1 ] && $compute_adjoint ; then
       ENDTIME=$(date +%s)
       Ttaken=$(($ENDTIME - $STARTTIME))
       echo "Adjoint simulation took $Ttaken seconds"
    fi
done

