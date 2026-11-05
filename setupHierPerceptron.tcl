# *********************************************************
# * Script Name  : Genus Legacy Mode initialization script
# *********************************************************
date

set LOCAL_DIR           "[exec pwd]/.."
set SYNTH_DIR           ${LOCAL_DIR}/work
set GPDK_ROOT           /usr/local/cadence/PDK/GPDK045/gsclib045_svt_v4.8/gsclib045
set GPDK_TECH_ROOT      /usr/local/cadence/PDK/GPDK045/gsclib045_svt_v4.8/gsclib045_tech
set TCL_PATH		"${LOCAL_DIR}/tcl ${LOCAL_DIR}/constraints"
set LIB_PATH            "${GPDK_ROOT}/timing ${GPDK_ROOT}/lef ${GPDK_TECH_ROOT}/lef" 
set QRC_TECH_FILE       /usr/local/cadence/PDK/GPDK045/gpdk045_v_6_0/qrc/typical/qrcTechFile
set RTL_PATH		"${LOCAL_DIR}/hdlfiles"
set DESIGN 		"perceptron"
# set WL_MODE		top

set MSGS_TO_BE_SUPRESSED {LBR-58 LBR-40 LBR-41 VLOGPT-35}


# Baseline Libraries

set LIB_LIST { \
		   slow_vdd1v0_multibitsDFF.lib \
		   slow_vdd1v0_basicCells.lib \
		   slow_vdd1v0_extvdd1v0.lib \
		   slow_vdd1v0_extvdd1v2.lib \
}

set LEF_LIST { \
		   gsclib045_tech.lef\
		   gsclib045_macro.lef \
		   gsclib045_multibitsDFF.lef \
}

# Baseline RTL
set RTL_LIST { \
		   perceptron.v \
		   sigmoid.v \
		   fmacc.v \
		   weightFIFO.v \
		   inputFIFO.v \
		   outputFIFO.v \
		   controller.v
}

#set CAP_TABLE_FILE ../libraries/tsmc13fsg.capTbl
suppress_messages {LBR-30 LBR-31 LBR-40 LBR-41 LBR-72 LBR-77 LBR-162}
set_db hdl_track_filename_row_col true 
set_db lp_power_unit mW 
set_db init_lib_search_path $LIB_PATH 
set_db script_search_path $TCL_PATH 
set_db init_hdl_search_path $RTL_PATH 
set_db auto_ungroup none

# set_db library $LIB_LIST
read_libs $LIB_LIST
read_hdl $RTL_LIST

## PLE
# set_db lef_library $LEF_LIST 
read_physical -lef $LEF_LIST
#set_db cap_table_file $CAP_TABLE_FILE 
set_db qrc_tech_file $QRC_TECH_FILE

