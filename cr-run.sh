#!/bin/bash

########## 1. parameters: YOU SHOULD CONFIRM ##########
DIVLINE=$(perl -E "print '=' x 20")
server_list="node005 node006 node007 node008 node009 node027 node028"
threads=16

function usage() {
cat <<EOF
Usage: $(basename "$0") <cov> <mode> [tag]

Required:
    cov   : 1.0 | 0.3 | 0.8
    mode  : mt | v3 | v3sim

Optional:
    tag   : extra suffix for SPEC_DIR (required when git is dirty)

Defaults:
    server_list="$server_list"
    threads=$threads

Examples:
    $(basename "$0") 0.3 v3
    $(basename "$0") 1.0 v3sim mytag
EOF
}

if [[ $1 == "-h" || $1 == "--help" ]]; then
        usage
        exit 0
fi

########## 2. env ##########
function set_env(){
    xs_pwd=$(pwd)
    cd ../
    . ./env.sh
    cd $xs_pwd
    export DRAMSIM3_HOME=/nfs/home/share/ci-workloads/DRAMsim3
    export NOOP_HOME=$xs_pwd
    echo "NEW NOOP_HOME: $NOOP_HOME"
    
    PERF_HOME=/nfs/home/share/liyanqin/env-scripts/perf

    gcc12O3_1=/nfs-nvme/home/share/checkpoints_profiles/spec06_rv64gcb_o3_20m_gcc12-fpcontr-off
    cpt_path_1=$gcc12O3_1/take_cpt
    cover1_path_1=$gcc12O3_1/json/o3_spec_fp_int-with-jemXalanc.json
    cover3_path_1=$PERF_HOME/json/gcc12o3-fpcontr-off-0.3.json
    cover8_path_1=$PERF_HOME/json/gcc12o3-fpcontr-off-0.8.json

    gcc12O3_2=/nfs/home/share/liyanqin/spec06_rv64gcb_O3_20m_gcc12.2.0-intFpcOff-jeMalloc
    cpt_path_2=$gcc12O3_2/checkpoint-0-0-0
    cover1_path_2=$gcc12O3_2/checkpoint-0-0-0/cluster-0-0.json
    cover3_path_2=$PERF_HOME/json/gcc12o3-incFpcOff-jeMalloc-0.3.json
    cover8_path_2=$PERF_HOME/json/gcc12o3-incFpcOff-jeMalloc-0.8.json

    SPEC17_GCC12_dir=/nfs/home/share/liyanqin/spec17-rv64gcb-O3-20m-gcc12.2.0-mix-with-special_wrf
    SPEC17_GCC12_cpt_PATH=$SPEC17_GCC12_dir/checkpoint-0-0-0/
    SPEC17_GCC12_json_PATH=$SPEC17_GCC12_dir/checkpoint-0-0-0/cluster-0-0.json
}
set_env

########## 3. config ##########
version="kunminghu"
cpt_path=$cpt_path_2
json_path=$cover1_path_2

is_dirty=$(git status --porcelain | wc -l)
if [[ $is_dirty -gt 0 ]]; then
    [[ $# -eq 3 ]] || { echo "[ERROR] git dirty: need 3 args -> <cov> <mode> <tag>"; exit 1; }
else
    [[ $# -eq 2 ]] || { echo "[ERROR] git clean: need 2 args -> <cov> <mode>"; exit 1; }
fi

cov=$1
mode=$2
if [[ $3 ]]; then
    tag="-$3"
else
    tag=""
fi

case $cov in 
"1.0")  json_path=$cover1_path_2;;
"0.3")  json_path=$cover3_path_2;;
"0.8")  json_path=$cover8_path_2;;
*)      echo "[ERROR] coverage needs to be 1.0/0.3/0.8"
        exit -1;;
esac

case $mode in 
"mt")       all_spec_dir="/nfs/home/share/`whoami`/perf-report-master";;
"v3")       all_spec_dir="/nfs/home/share/`whoami`/perf-report-kmhv3";;
"v3sim")    all_spec_dir="/nfs/home/share/`whoami`/perf-report-kmhv3-simfrontend";;
"getname")  echo "[NOTE] only get the name of SPEC_DIR"
            all_spec_dir="/nfs/home/share/liyanqin/perf-report-kmhv3"
            ;;
*)          echo "[ERROR] mode needs to be mt/v3/v3sim"
            exit -1;;
esac

SHORT_SHA=$(git rev-parse --short HEAD)
DATE=$(git show -s --format=%cd --date=format:%y%m%d HEAD)
SPEC_DIR="$all_spec_dir/cr${DATE}-${SHORT_SHA}$tag"
echo "$SPEC_DIR"
if [[ $mode == "getname" ]]; then
    exit 0
fi

########## 4. make ##########
echo "========== make start at $(date): $SPEC_DIR =========="
if [ -e "$SPEC_DIR/emu" ]; then
    mkdir -p $NOOP_HOME/build
    cp $SPEC_DIR/emu $NOOP_HOME/build/emu
    cp $SPEC_DIR/constantin.txt $NOOP_HOME/build/constantin.txt
else
    python3 $NOOP_HOME/scripts/xiangshan.py --clean
    if [ "$mode" == "v3sim" ] ; then
        python3 $NOOP_HOME/scripts/xiangshan.py --build \
            --yaml-config $NOOP_HOME/src/main/resources/config/Default.yml \
            --dramsim3 $DRAMSIM3_HOME --with-dramsim3 \
            --threads $threads --trace-fst \
            --simfrontend
    else        
        python3 $NOOP_HOME/scripts/xiangshan.py --build \
            --dramsim3 $DRAMSIM3_HOME --with-dramsim3 \
            --threads $threads --trace-fst \
            --pgo $NOOP_HOME/ready-to-run/coremark-2-iteration.bin \
            --llvm-profdata llvm-profdata
    fi
    mkdir -p $SPEC_DIR
    cp $NOOP_HOME/build/emu $SPEC_DIR/emu
    cp $NOOP_HOME/build/constantin.txt $SPEC_DIR/constantin.txt.bak
    if [ -e "$SPEC_DIR/constantin.txt" ]; then
        cp $SPEC_DIR/constantin.txt $NOOP_HOME/build/constantin.txt
    else
        cp $NOOP_HOME/build/constantin.txt $SPEC_DIR/constantin.txt
    fi
fi
echo "========== make end at $(date): $SPEC_DIR =========="

########## 5. run ##########
echo "********** cal start at $(date): $SPEC_DIR **********"
cd $PERF_HOME
if [ "$mode" == "v3sim" ]; then
    python3 xs_autorun_multiServer.py $cpt_path $json_path --xs $NOOP_HOME --threads $threads --dir $SPEC_DIR --sim-front --resume -L "$server_list"
else
    python3 xs_autorun_multiServer.py $cpt_path $json_path --xs $NOOP_HOME --threads $threads --dir $SPEC_DIR --resume -L "$server_list"
fi
mv $NOOP_HOME/build/*.db $SPEC_DIR/ || true
mv $NOOP_HOME/build/*.vcd $SPEC_DIR/ || true
echo "********** cal end at $(date): $SPEC_DIR **********"

########## 6. score ##########
python3 xs_autorun_multiServer.py $cpt_path $json_path --xs $NOOP_HOME --threads $threads --dir $SPEC_DIR --report > $SPEC_DIR/score.txt
