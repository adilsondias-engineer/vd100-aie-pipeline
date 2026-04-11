set SynModuleInfo {
  {SRCNAME s2mm MODELNAME s2mm RTLNAME s2mm IS_TOP 1
    SUBMODULES {
      {MODELNAME s2mm_gmem_m_axi RTLNAME s2mm_gmem_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME s2mm_control_s_axi RTLNAME s2mm_control_s_axi BINDTYPE interface TYPE interface_s_axilite}
      {MODELNAME s2mm_regslice_both RTLNAME s2mm_regslice_both BINDTYPE interface TYPE adapter IMPL reg_slice}
      {MODELNAME s2mm_flow_control_loop_pipe RTLNAME s2mm_flow_control_loop_pipe BINDTYPE interface TYPE internal_upc_flow_control INSTNAME s2mm_flow_control_loop_pipe_U}
    }
  }
}
