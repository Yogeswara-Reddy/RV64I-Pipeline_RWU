
`timescale 1ns/1ps

import as_pack::*;

module tb_rv64i ();
  parameter tclk_2_t = 500; // 10 ns; given by timescale
  parameter clk_2_t = 5;   // 5 ns; given by timescale
  parameter clk_80_t = 400;

  parameter sc01_length_in = 2;
  parameter sc01_length_out = 2;
  parameter im_length_in = 4;
  parameter im_length_out = 4;
  parameter scan_lenght     = 4;
  parameter scan_lenght_in  = 2;
  parameter scan_lenght_out = 2;
  

  logic clk_s, clk_core_s;
  logic	rst_s;
  logic	tck_s, trst_s, tms_s, tdi_s, tdo_s;
  tri [nr_gpios-1:0]	      gpio_s;
  logic			      cs_s;

  // initial load I-Mem
  logic [instr_width-1:0]     iram_s[imemdepth-1:0]; // I-Mem
  logic	[instr_width-1:0]     instr_s;               // one instruction

  logic	[imem_addr_width-1:0] imScanAddr_s;
  logic [instr_width-1:0]     imScanData_s;
  logic			      imScanWe_s;
  logic [im_scan_length-1:0]  imScanTdi_s;

  logic			      test_case_s;
  
  
  int fd;

  int cnt = 0;
  
  
  as_top_mem DUT (.clk_i(clk_s),
              .rst_i(rst_s),
              .tck_i(tck_s),
              .trst_i(trst_s),
              .tms_i(tms_s),
              .tdi_i(tdi_s),
              .tdo_o(tdo_s),
              .gpio_io(gpio_s),
              .cs_o(cs_s)
             );
  // read instructions
  initial
    $readmemh("riscvtest.mem",iram_s);

  assign instr_s = iram_s[0];

  initial
  begin
    fd = $fopen("./error.txt", "a");
    trst_s <= 0;
    tdi_s  <= 0;
    tms_s  <= 0;
  end
  
  // clock
  /*always
  begin
    clk_s <= 1; #clk_2_t; clk_s <= 0; #clk_2_t; 
  end*/

  always
  begin
    clk_core_s <= 1; #clk_80_t; clk_core_s <= 0; #clk_80_t; // not needed here
  end
  
  // TCK
  always
  begin
    tck_s <= 0; #tclk_2_t; tck_s <= 1; #tclk_2_t; 
  end

  // Scan-Test
  initial
  begin
    test_case_s = 0;
    
    clk_s = 1'b0;
    rst_s = 1'b1;
    #(tclk_2_t/2);
    jtag_sw_rst(tclk_2_t);          // TAPC Soft-Reset
    test_case_s = ~test_case_s;
    jtag_load_ir(tclk_2_t, 8'h81);  // Load IR with 129, which is (dummy) scan-test
    test_case_s = ~test_case_s;
    rst_s = 1'b0;

    jtag_shift_in_out_capture(tclk_2_t, 2'b00, 2'b00); // 00 - 0
    test_case_s = ~test_case_s;
    jtag_shift_in_out_capture(tclk_2_t, 2'b01, 2'b00); // 01 - 0
    test_case_s = ~test_case_s;
    jtag_shift_in_out_capture(tclk_2_t, 2'b10, 2'b00); // 10 - 0
    test_case_s = ~test_case_s;
    jtag_shift_in_out_capture(tclk_2_t, 2'b11, 2'b00); // 11 - 1
    test_case_s = ~test_case_s;
    jtag_shift_in_out_capture(tclk_2_t, 2'b00, 2'b00); // 00 - 0
    test_case_s = ~test_case_s;
    #(50*2*tclk_2_t);
  end // initial begin

  

  // check results
  always @(posedge clk_s) // here: clk_s pulses only once in a test and only in a test
  begin
    #(4*tclk_2_t); // delay
    
    if(tdo_s === 1)
    begin
      cnt++;	
      $display("TDO=1 detected: %d", cnt);
      if(cnt === 5) $stop;   // 5 tests
    end
    else if(tdo_s === 0)
    begin
      cnt++;
      $display("TDO=0 detected: %d", cnt);
      if(cnt === 5) $stop;
    end
  end

//------------------------------------------
// Functions
//------------------------------------------

  task jtag_sw_rst(int cl_2_t);
  begin
    tms_s = 1; #(5*2*cl_2_t);
  end
  endtask // jtag_sw_rst

  task jtag_load_ir(int cl_2_t, logic [7:0] ir);
  begin
    // from reset
    tms_s = 0; #(2*cl_2_t); // Run-Test-Idle
    tms_s = 1; #(2*cl_2_t); // Select-DR-Scan
    tms_s = 1; #(2*cl_2_t); // Select-IR-Scan
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Capture-IR
    tdi_s = ir[7]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[6]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[5]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[4]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[3]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[2]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[1]; tms_s = 0; #(2*cl_2_t); // Shift-IR
    tdi_s = ir[0]; tms_s = 1; #(2*cl_2_t); // Exit1-IR
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Update-IR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Run-Test_idle
  end
  endtask // jtag_load_ir

  task jtag_shift_in_out_capture(int cl_2_t, logic [scan_lenght_in-1:0] dr_in, logic [scan_lenght_out-1:0] dr_out);
  begin
    // from run-test-idle
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // -> Select-DR-Scan
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // -> Capture-DR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // -> Shift-DR
    for(int i=scan_lenght_in-1;i>0;i--)
    begin
      tdi_s = dr_in[i]; tms_s = 0; #(2*cl_2_t); // -> Shift-DR
    end
    tdi_s = dr_in[0]; tms_s = 1; #(2*cl_2_t); // -> Exit1-DR
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // -> Update-DR
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // -> Select-DR-Scan
    tdi_s = 0; tms_s = 0; #(cl_2_t); clk_s = 1'b1; #(cl_2_t/2); clk_s = 1'b0; #(cl_2_t/2); // -> Capture-DR; ONE clock pulse
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // -> Shift-DR
    for(int i=scan_lenght_out-1;i>0;i--)
    begin
      tdi_s = dr_out[i]; tms_s = 0; #(2*cl_2_t); // -> Shift-DR
    end
    tdi_s = dr_out[0]; tms_s = 1; #(2*cl_2_t); // -> Exit1-DR
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // -> Update-DR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // -> RTI
  end
  endtask

  task jtag_shift_in_dr_to_pause(int cl_2_t, logic [sc01_length_in-1:0] dr);
  begin
    // from run-test-idle
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Select-DR-Scan
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Capture-DR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Shift-DR ??
    for(int i=sc01_length_in-1;i>0;i--)
    begin
      tdi_s = dr[i]; tms_s = 0; #(2*cl_2_t); // Shift-DR
    end
    tdi_s = dr[0]; tms_s = 1; #(2*cl_2_t); // Exit1-DR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Pause-DR
  end
  endtask // jtag_shift_in_dr_to_pause

  task jtag_shift_out_dr(int cl_2_t);
  begin
    // from pause
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Exit2-DR;
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Shift-DR; // shift out ??
    for(int i=sc01_length_out-1;i>0;i--)
    begin
      tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Shift-DR; // shift out
    end
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Exit1-DR  // shift out
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Update-DR;
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Run-Test_idle
  end
  endtask // jtag_shift_in_dr_to_pause

  task jtag_shift_in_imdr_to_rti(int cl_2_t, logic [im_length_in-1:0] dr);
  begin
    // from run-test-idle
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Select-DR-Scan
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Capture-DR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Shift-DR ??
    for(int i=im_length_in-1;i>0;i--)
    begin
      tdi_s = dr[i]; tms_s = 0; #(2*cl_2_t); // Shift-DR
    end
    tdi_s = dr[0]; tms_s = 1; #(2*cl_2_t); // Exit1-DR
    tdi_s = 0; tms_s = 1; #(2*cl_2_t); // Update-DR
    tdi_s = 0; tms_s = 0; #(2*cl_2_t); // Run-Test_idle
  end
  endtask

  function string get_time();
    int    file_pointer;
    
    //Stores time and date to file sys_time
    //void'($system("date +%X--%x > sys_time"));
    void'($system("date +%x > sys_time"));
    //Open the file sys_time with read access
    file_pointer = $fopen("sys_time","r");
    //assin the value from file to variable
    void'($fscanf(file_pointer,"%s",get_time));
    //close the file
    $fclose(file_pointer);
    void'($system("rm sys_time"));
  endfunction

endmodule : tb_rv64i
