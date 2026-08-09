`default_nettype none

module qrs_detector (
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire [15:0] mwi_in,
    output reg beat_detected,
    output reg [15:0] rr_interval,      // samples between beats, to feature_extractor
    output reg [15:0] beat_amplitude,   // MWI peak value at detection, to feature_extractor
    output reg [15:0] qrs_start_time,   // sample counter at threshold crossing
    output reg [15:0] qrs_peak_time     // sample counter at peak
);

localparam WAITING = 2'b00, CANDIDATE = 2'b01, REFRACTORY = 2'b10;
localparam refractory_period = 7'd100;

reg [1:0] state;
reg [15:0] spk_i;
reg [15:0] npk_i;
wire [15:0] threshold_i;
reg [15:0] sample_counter;
reg [15:0] mwi_peak;
reg [15:0] refractory_counter;
reg [15:0] current_rr;

assign threshold_i = npk_i + ((spk_i - npk_i) >> 2);

always @(posedge clk) begin
    beat_detected <= 1'b0;
    if(!rst_n) begin
        state <= WAITING;
        spk_i <= 16'd100;
        npk_i <= 16'd50;
        rr_interval <= 0;
        beat_amplitude <= 0;
        qrs_start_time <= 0;
        qrs_peak_time <= 0;
        mwi_peak <= 0;
        refractory_counter <= 0;
        sample_counter <= 0;
        current_rr <= 0;
    end else begin
        if(sample_valid) begin
            sample_counter <= sample_counter + 1'b1;
            case(state)
                WAITING: begin
                    current_rr <= current_rr + 1'b1;

                    if(mwi_in > threshold_i) begin
                        qrs_start_time <= sample_counter;
                        qrs_peak_time <= sample_counter;
                        mwi_peak <= mwi_in;
                        state <= CANDIDATE;
                    end else begin
                        npk_i <= (mwi_in >>> 3) + (npk_i - (npk_i >>> 3));
                    end
                end
                CANDIDATE: begin
                    current_rr <= current_rr + 1'b1;
                    if(mwi_in > mwi_peak) begin
                        mwi_peak <= mwi_in;
                        qrs_peak_time <= sample_counter;
                    end
                    if(mwi_in < threshold_i) begin
                        spk_i <= (mwi_peak >>> 3) + (spk_i - (spk_i >> 3));
                        beat_detected <= 1'b1;
                        beat_amplitude <= mwi_peak;
                        refractory_counter <= 0;
                        rr_interval <= current_rr; 
                        current_rr <= 0;
                        state <= REFRACTORY;
                    end
                end
                REFRACTORY: begin
                    refractory_counter <= refractory_counter + 1'b1;
                    if(refractory_counter >= refractory_period) begin
                        refractory_counter <= 0;
                        state <= WAITING;
                    end else begin
                    end
                end
                default: state <= WAITING;
            endcase
        end
    end
end



endmodule