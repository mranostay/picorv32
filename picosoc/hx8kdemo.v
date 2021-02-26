/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

module hx8kdemo (
	input clk,

	output ser_tx,
	input ser_rx,

	output [31:0] leds,
	output [11:0] segs,
	input  [23:0] dip,
	input  [4 :0] sw,

	output flash_csb,
	output flash_clk,
	inout  flash_io0,
	inout  flash_io1,
	inout  flash_io2,
	inout  flash_io3
);

	wire clk_pll, locked;

	pll pll (
		.clock_in (clk),
		.clock_out(clk_pll),
		.locked   (locked)
	);

	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt & locked;

	always @(posedge clk_pll) begin
		reset_cnt <= reset_cnt + !resetn;
	end

	wire flash_io0_oe, flash_io0_do, flash_io0_di;
	wire flash_io1_oe, flash_io1_do, flash_io1_di;
	wire flash_io2_oe, flash_io2_do, flash_io2_di;
	wire flash_io3_oe, flash_io3_do, flash_io3_di;

	SB_IO #(
		.PIN_TYPE(6'b 1010_01),
		.PULLUP(1'b 0)
	) flash_io_buf [3:0] (
		.PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
		.OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
		.D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
		.D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
	);

	wire        iomem_valid;
	reg         iomem_ready;
	wire [3:0]  iomem_wstrb;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	reg  [31:0] iomem_rdata;

	reg [7:0] gpio [0:1][0:3];
	reg [7:0] steps = 0;
	reg [2:0] digit = 0;
	reg [14:0] cnt;

	assign leds[ 7: 0] = cnt < (steps * 255) ? gpio[0][0] : 8'b0;
	assign leds[15: 8] = cnt < (steps * 255) ? gpio[0][1] : 8'b0;
	assign leds[23:16] = cnt < (steps * 255) ? gpio[0][2] : 8'b0;
	assign leds[31:24] = cnt < (steps * 255) ? gpio[0][3] : 8'b0;
	assign segs = { cnt < (steps * 255) ? ~(4'b1000 >> digit) : 4'b1111, gpio[1][digit] };

	integer idx;
	integer i;

	always @(posedge clk_pll) begin
		if (!resetn) begin
            for (i = 0; i < 4; i = i + 1) begin
			    gpio[0][i] <= 0;
			    gpio[1][i] <= 0;
            end
		end else begin
			iomem_ready <= 0;
			idx = iomem_addr[7:0] / 4;
			if (iomem_valid && !iomem_ready) begin
				if (iomem_addr[31:24] == 8'h 03) begin
					iomem_ready <= 1;
					iomem_rdata[ 7: 0] <= gpio[idx][0];
					iomem_rdata[15: 8] <= gpio[idx][1];
					iomem_rdata[23:16] <= gpio[idx][2];
					iomem_rdata[31:24] <= gpio[idx][3];
					if (iomem_wstrb[0]) gpio[idx][0] <= iomem_wdata[ 7: 0];
					if (iomem_wstrb[1]) gpio[idx][1] <= iomem_wdata[15: 8];
					if (iomem_wstrb[2]) gpio[idx][2] <= iomem_wdata[23:16];
					if (iomem_wstrb[3]) gpio[idx][3] <= iomem_wdata[31:24];
				end else if (iomem_addr[31:24] == 8'h 04) begin
					iomem_ready <= 1;
					iomem_rdata[ 7: 0] <= dip[ 7: 0];
					iomem_rdata[15: 8] <= dip[15: 8];
					iomem_rdata[23:16] <= dip[23:16];
					iomem_rdata[31:24] <= 0;
				end else if (iomem_addr[31:24] == 8'h 05) begin
					iomem_ready <= 1;
					iomem_rdata[ 7: 0] <= steps[ 7: 0];
					if (iomem_wstrb[0]) steps <= iomem_wdata[ 7: 0];
				end
			end
        end
    end

	always @(posedge clk_pll) begin
		cnt <= cnt + 1;
	end

	always @(posedge clk_pll) begin
		if (!cnt) digit <= digit + 1;
	end

	picosoc soc (
		.clk          (clk_pll     ),
		.resetn       (resetn      ),

		.ser_tx       (ser_tx      ),
		.ser_rx       (ser_rx      ),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.irq_5        (1'b0        ),
		.irq_6        (1'b0        ),
		.irq_7        (1'b0        ),

		.iomem_valid  (iomem_valid ),
		.iomem_ready  (iomem_ready ),
		.iomem_wstrb  (iomem_wstrb ),
		.iomem_addr   (iomem_addr  ),
		.iomem_wdata  (iomem_wdata ),
		.iomem_rdata  (iomem_rdata )
	);

endmodule
