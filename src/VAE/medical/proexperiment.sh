#!/usr/bin/env bash

set -x
set -e

FILENAME=$(basename -- "$1")
NAME="${FILENAME%.*}"

PROU=plgath0m
PRO_ATT_DIR=/net/people/$PROU/scratch/medical

DIR=scratch_runs/$NAME

SUFFIX=$(date +%Y%m%d%H%M%S)
PRO_DIR=$PRO_ATT_DIR/$DIR/$SUFFIX

TMP_DIR=$(mktemp -d)

S3_BUCKET=notebooks.ath0m.com
OUTPUT=s3://$S3_BUCKET/$NAME/${NAME}_${SUFFIX}.ipynb

DATASET_PATH=$PRO_ATT_DIR/datasets/small-medical-22.h5

cat > $TMP_DIR/job.sbatch <<EOF
#!/bin/bash -l
#SBATCH -J ${NAME}
#SBATCH -N 1
#SBATCH -c 1
#SBATCH --gres=gpu:1
#SBATCH --mem=32GB
#SBATCH --time=12:00:00
#SBATCH -A asrsonata
#SBATCH -p plgrid-gpu
#SBATCH --output="$PRO_DIR/exp.out"
#SBATCH --error="$PRO_DIR/exp.err"

conda activate medical
cd $PRO_DIR
srun /bin/hostname
srun papermill $FILENAME $OUTPUT -p dataset_path $DATASET_PATH -p hyperdash True -p save_model True ${@:2:99}
EOF

ssh -q $PROU@pro.cyfronet.pl mkdir -p $PRO_DIR $PRO_DIR/checkpoints

rsync -azhP -e "ssh -q" $TMP_DIR/ $PROU@pro.cyfronet.pl:$PRO_DIR/
rsync -azhP -e "ssh -q" $1 $PROU@pro.cyfronet.pl:$PRO_DIR/

ssh -q $PROU@pro.cyfronet.pl sbatch $PRO_DIR/job.sbatch

rm -Rf $TMP_DIR

echo "Queue status"
ssh -q $PROU@pro.cyfronet.pl squeue