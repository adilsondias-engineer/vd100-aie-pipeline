set SynModuleInfo {
  {SRCNAME mm2s MODELNAME mm2s RTLNAME mm2s IS_TOP 1
    SUBMODULES {
      {MODELNAME mm2s_gmem_m_axi RTLNAME mm2s_gmem_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME mm2s_control_s_axi RTLNAME mm2s_control_s_axi BINDTYPE interface TYPE interface_s_axilite}
      {MODELNAME mm2s_regslice_both RTLNAME mm2s_regslice_both BINDTYPE interface TYPE adapter IMPL reg_slice}
      {MODELNAME mm2s_flow_control_loop_pipe RTLNAME mm2s_flow_control_loop_pipe BINDTYPE interface TYPE internal_upc_flow_control INSTNAME mm2s_flow_control_loop_pipe_U}
    }
  }
}
