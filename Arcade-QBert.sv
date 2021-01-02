//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [45:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output [11:0] VIDEO_ARX,
    output [11:0] VIDEO_ARY,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output [1:0]  VGA_SL,
    output        VGA_SCALER, // Force VGA scaler

    // Use framebuffer from DDRAM (USE_FB=1 in qsf)
    // FB_FORMAT:
    //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
    //    [3]   : 0=16bits 565 1=16bits 1555
    //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
    //
    // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
    output        FB_EN,
    output  [4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output  [7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO, // 24.576 MHz
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //High latency DDR3 RAM interface
    //Use for non-critical time purposes
    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output  [7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output  [7:0] DDRAM_BE,
    output        DDRAM_WE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    input   [6:0] USER_IN,
    output  [6:0] USER_OUT,

    input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_USER  = ioctl_download;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
    "QBert;;",
    "-;",
    "F1,bin,Rom Load;",
    "O5,Orientation,Vert,Horz;",
    "OFH,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "O8,Aspect ratio,Original,Full Screen;",
    "-;",
    "O6,Test mode,Off,On;",
    "-;",
    "P1-;",
    "P1,Dip Switch;",
    "P1-;",
    "P1OA,Demo Mode,Normal,Infinite Lives;",
    "P1OB,Attract Play,Sound,No Sound;",
    "P1OC,Normal/Free,Normal,Free;",
    "P1OD,Game Mode,Upright,Cocktail;",
    "P1OE,Kicker,Off,On;",
    "-;",
    "T0,Reset;",
    "R0,Reset and close OSD;",
    "V,v",`BUILD_DATE
};

wire forced_scandoubler;
// wire direct_video;
wire [21:0] gamma_bus;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [15:0] joystick_0;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),
    .EXT_BUS(),
    .gamma_bus(gamma_bus),
	// .direct_video(direct_video),

    .conf_str(CONF_STR),
    .forced_scandoubler(forced_scandoubler),

    .buttons(buttons),
    .status(status),
    // .status_menumask({direct_video}),

    .ps2_key(ps2_key),

    .ioctl_download(ioctl_download),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_wait(ioctl_wait),
    .ioctl_index(ioctl_index),

    .joystick_0(joystick_0)
);

///////////////////////   CLOCKS   ///////////////////////////////

// ** Video
// XTAL = 20M
// CLK = 10M
// HCLK = 5M
// ** CPU
// XTAL = 15M
// CPU_CLK from 8284 = 5M

wire clk_sys, clk_100, clk_40, clk_10;
pll pll
(
    .refclk(CLK_50M),
    .rst(0),
    .outclk_0(clk_sys),
    .outclk_1(clk_100),
    .outclk_2(clk_40),
	 .outclk_3(clk_10)
);

reg [3:0] cnt1;
reg cpu_clk; // clock enable
always @(posedge clk_sys) begin
  cnt1 <= cnt1 + 4'd1;
  if (cnt1 == 4'd9) begin
    cnt1 <= 4'd0;
    cpu_clk <= 1'b1;
  end
  else cpu_clk <= 1'b0;
end

// derive sound clock from clk_sys
reg [5:0] cnt2;
reg clk_2;
always @(posedge clk_sys) begin
    cnt2 <= cnt2 + 6'd1;
	 clk_2 <= 1'b0;
    if (cnt2 == 6'd33) begin
        cnt2 <= 6'd0;
        clk_2 <= 1'b1;
    end
end

reg clk_5;
always @(posedge clk_10)
	clk_5 <= ~clk_5;

wire ce_pix = clk_5;


wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;

wire [5:0] OP2720;
wire [7:0] audio;

wire [7:0] red, green, blue;

assign AUDIO_L = { audio, 8'd0 };
assign AUDIO_R = { audio, 8'd0 };

wire [7:0] IP1710 = {
    joystick_0[4], // test 1
    ~status[6],    // test 2
    2'b0,
    joystick_0[6], // coin 2
    joystick_0[7], // coin 1
    joystick_0[5], // p2
    joystick_0[4]  // p1
};

wire [7:0] IP4740 = {
    4'b0,
    joystick_0[2], // left
    joystick_0[3], // right
    joystick_0[1], // up
    joystick_0[0]  // down
};

mylstar_board mylstar_board
(
    .clk_sys(clk_sys),
    .reset(reset),

    .CLK(clk_10),
    .CLK5(clk_5),

    .CPU_CORE_CLK(clk_100),
    .CPU_CLK(cpu_clk),

    .HBlank(HBlank),
    .HSync(HSync),
    .VBlank(VBlank),
    .VSync(VSync),

    .red(red),
    .green(green),
    .blue(blue),

    .IP1710(IP1710),
    .IP4740(IP4740),
    .OP2720(OP2720),
    .OP3337(),

    .dip_switch({ // not sure, pls check
        2'b0,
        status[14], // kicker
        1'b0,
        status[13], // game mode
        status[12], // normal/free
        status[11], // sound
        status[10]  // demo mode
    }),

    .rom_init(ioctl_download),
    .rom_init_address(ioctl_addr),
    .rom_init_data(ioctl_dout)
);

// audio board
ma216_board ma216_board(
    .clk(clk_2),
    .clk_sys(clk_sys),
    .reset(reset),
    .IP2720(OP2720),
    .audio(audio),
    .rom_init(ioctl_download),
    .rom_init_address(ioctl_addr),
    .rom_init_data(ioctl_dout)
);

// 256x240 15KHz 60Hz

wire rotate_ccw = 1'b1;
wire no_rotate = status[5];
screen_rotate screen_rotate (.*);

arcade_video #(256,24) arcade_video
(
	.*,
	.clk_video(clk_40),
	.RGB_in({ red, green, blue }),
	.fx(status[17:15])
);

//reg ce_pix;
//always @(posedge clk_10)
//    ce_pix <= ~ce_pix;

endmodule
