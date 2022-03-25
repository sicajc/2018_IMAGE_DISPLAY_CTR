module LCD_CTRL(clk,
                reset,
                cmd,
                cmd_valid,
                IROM_Q,
                IROM_rd,
                IROM_A,
                IRAM_valid,
                IRAM_D,
                IRAM_A,
                busy,
                done);
    input clk;
    input reset;
    input [3:0] cmd;
    input cmd_valid;
    input [7:0] IROM_Q;
    output IROM_rd;
    output [5:0] IROM_A;
    output IRAM_valid;
    output [7:0] IRAM_D;
    output [5:0] IRAM_A;
    output busy;
    output done;

    /*----------------PARAMETERS----------------*/
    parameter IMAGE_WIDTH      = 8;
    parameter DATA_WIDTH       = 8;
    parameter ADDR_WIDTH       = 6;
    parameter OP_POINTER_WIDTH = 3;
    /*----------------STATES--------------------*/
    parameter INITIAL        = 'd0;
    parameter LOAD_IMAGE     = 'd1;
    parameter IDLE           = 'd2;
    parameter IMAGE_WB       = 'd3;
    parameter DONE           = 'd4;
    parameter ARITHMETIC_CAL = 'd5;
    parameter ARITHMETIC_WB  = 'd6;
    parameter DISPLACE_WB    = 'd7;

    /*----------------CMD-----------------------*/
    parameter  WR        = 4'b0000  ;
    parameter  SHF_UP    = 4'b0001  ;
    parameter  SHF_DOWN  = 4'b0010  ;
    parameter  SHF_RIGHT = 4'b0100  ;
    parameter  SHF_LEFT  = 4'b0011  ;
    parameter  MAX       = 4'b0101  ;
    parameter  MIN       = 4'b0110  ;
    parameter  AV        = 4'b0111  ;
    parameter  CCR       = 4'b1000  ;
    parameter  CR        = 4'b1001  ;
    parameter  MX        = 4'b1010  ;
    parameter  MY        = 4'b1011  ;

    wire CMD_WR        = cmd == WR;
    wire CMD_SHF_UP    = cmd == SHF_UP;
    wire CMD_SHF_DOWN  = cmd == SHF_DOWN;
    wire CMD_SHF_RIGHT = cmd == SHF_RIGHT;
    wire CMD_SHF_LEFT  = cmd == SHF_LEFT;
    wire CMD_MAX       = cmd == MAX;
    wire CMD_MIN       = cmd == MIN;
    wire CMD_AV        = cmd == AV ;
    wire CMD_CCR       = cmd == CCR ;
    wire CMD_CR        = cmd == CR ;
    wire CMD_MX        = cmd == MX;
    wire CMD_MY        = cmd == MY;


    /*----------------Memory--------------------*/
    reg[IMAGE_WIDTH-1:0] image_mem[0:IMAGE_WIDTH-1];

    /*----------------REGISTERS-----------------*/
    reg[OP_POINTER_WIDTH-1:0] operation_point_x_reg;
    reg[OP_POINTER_WIDTH-1:0] operation_point_y_reg;
    reg[DATA_WIDTH-1:0] AR_temp_reg;

    /*-----------------FLAGS--------------------*/
    wire  ld_image_done_flag;
    wire  image_wb_done_flag;
    wire image_right_end_reach_flag  = operation_point_x_reg == IMAGE_WIDTH;
    wire image_bottom_end_reach_flag = operation_point_y_reg == IMAGE_WIDTH;

    wire right_boundary_reach_flag = operation_point_x_reg == IMAGE_WIDTH-1;
    wire left_boundary_reach_flag  = operation_point_x_reg == 'd1;
    wire upper_boundary_reach_flag = operation_point_y_reg == 'd1;
    wire lower_boundary_reach_flag = operation_point_y_reg == IMAGE_WIDTH-1;

    assign ld_image_done_flag = image_bottom_end_reach_flag;

    /*----------------2X2_PROCESS_IMAGE------------*/
    reg[DATA_WIDTH-1:0] process_image_one_one ;
    reg[DATA_WIDTH-1:0] process_image_one_two ;
    reg[DATA_WIDTH-1:0] process_image_two_one ;
    reg[DATA_WIDTH-1:0] process_image_two_two ;

    wire[OP_POINTER_WIDTH-1:0]  process_image_one_one_addr_x = operation_point_x_reg - 1;
    wire[OP_POINTER_WIDTH-1:0]  process_image_one_one_addr_y = operation_point_y_reg - 1;

    wire[OP_POINTER_WIDTH-1:0]  process_image_one_two_addr_x = operation_point_x_reg;
    wire[OP_POINTER_WIDTH-1:0]  process_image_one_two_addr_y = operation_point_y_reg - 1;

    wire[OP_POINTER_WIDTH-1:0]  process_image_two_one_addr_x = operation_point_x_reg - 1;
    wire[OP_POINTER_WIDTH-1:0]  process_image_two_one_addr_y = operation_point_y_reg;

    wire[OP_POINTER_WIDTH-1:0]  process_image_two_two_addr_x = operation_point_x_reg;
    wire[OP_POINTER_WIDTH-1:0]  process_image_two_two_addr_y = operation_point_y_reg;

    /*----------------Arithmetic_output-------------*/
    reg[DATA_WIDTH-1:0] AR_out;

    /*------------------MAIN----------------*/
    reg[3:0] current_state,next_state;

    wire STATE_INITIAL        = current_state == INITIAL ;
    wire STATE_LOAD_IMAGE     = current_state == LOAD_IMAGE ;
    wire STATE_IDLE           = current_state == IDLE ;
    wire STATE_IMAGE_WB       = current_state == IMAGE_WB ;
    wire STATE_DONE           = current_state == DONE ;
    wire STATE_ARITHMETIC_CAL = current_state == ARITHMETIC_CAL ;
    wire STATE_ARITHMETIC_WB  = current_state == ARITHMETIC_WB ;
    wire STATE_DISPLACE_WB    = current_state == DISPLACE_WB ;


    //MAIN CTR
    always @(posedge clk or posedge reset)
    begin
        current_state <= reset ? IDLE : next_state;
    end

    always @(*)
    begin
        case(current_state)
            INITIAL:
            begin
                next_state = LOAD_IMAGE;
            end
            LOAD_IMAGE:
            begin
                next_state = ld_image_done_flag ? IDLE : LOAD_IMAGE;
            end
            IDLE:
            begin
                if (cmd_valid)
                begin
                    case(cmd)
                        WR:
                        begin
                            next_state = IMAGE_WB;
                        end
                        SHF_UP,SHF_DOWN,SHF_LEFT,SHF_RIGHT:
                        begin
                            next_state = IDLE;
                        end
                        MAX,MIN,AV:
                        begin
                            next_state = ARITHMETIC_CAL;
                        end
                        CCR,CR,MX,MY:
                        begin
                            next_state = DISPLACE_WB;
                        end
                        default:
                        begin
                            next_state = IDLE;
                        end
                    endcase
                end
                else
                begin
                    next_state = IDLE;
                end
            end
            IMAGE_WB:
            begin
                next_state = image_wb_done_flag ? DONE : IMAGE_WB;
            end
            DONE:
            begin
                next_state = INITIAL;
            end
            ARITHMETIC_CAL:
            begin
                next_state = ARITHMETIC_WB;
            end
            ARITHMETIC_WB :
            begin
                next_state = IDLE;
            end
            DISPLACE_WB :
            begin
                next_state = IDLE;
            end
            default:
            begin
                next_state = IDLE;
            end
        endcase
    end

    //image_mem
    integer i;
    integer j;
    always @(posedge clk or posedge reset)
    begin
        for(i = 0;i<IMAGE_WIDTH;i = i+1)
            for(j = 0;j<IMAGE_WIDTH;j = j+1)
            begin
                if (reset)
                begin
                    image_mem[i][j] <= 'd0;
                end
                else
                begin
                    case(current_state)
                        LOAD_IMAGE:
                        begin
                            image_mem[operation_point_y_reg][operation_point_x_reg] <= IROM_Q;
                        end
                        ARITHMETIC_WB,DISPLACE_WB:
                        begin
                            image_mem[process_image_one_one_addr_y][process_image_one_one_addr_x] <= process_image_one_one;
                            image_mem[process_image_one_two_addr_y][process_image_one_two_addr_x] <= process_image_one_two;
                            image_mem[process_image_two_one_addr_y][process_image_two_one_addr_x] <= process_image_two_one;
                            image_mem[process_image_two_two_addr_y][process_image_two_two_addr_x] <= process_image_two_two;
                        end
                        default:
                        begin
                            image_mem[i][j] <= image_mem[i][j];
                        end
                    endcase
                end
            end
    end

    //ADDR CONVERTER and addr signals
    wire[ADDR_WIDTH-1:0] addr = operation_point_y_reg * IMAGE_WIDTH +  operation_point_x_reg;
    assign IROM_A             = STATE_LOAD_IMAGE ? addr : 'z;
    assign IRAM_A             = STATE_IMAGE_WB ? addr : 'z;

    //operation_point_x_reg & operation_point_y_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            operation_point_x_reg <= 'd0;
            operation_point_y_reg <= 'd0;
        end
        else
        begin
            case(current_state)
                LOAD_IMAGE,IMAGE_WB:
                begin
                    operation_point_x_reg <= image_bottom_end_reach_flag ? 'd1 : image_right_end_reach_flag ? 'd0 : operation_point_x_reg + 1;
                    operation_point_y_reg <= image_bottom_end_reach_flag ? 'd1 : image_right_end_reach_flag ? operation_point_y_reg + 1 : operation_point_y_reg;
                end
                IDLE:
                begin
                    if (cmd_valid)
                    begin
                        case(cmd)
                            WR:
                            begin
                                operation_point_y_reg <= 'd0;
                                operation_point_x_reg <= 'd0;
                            end
                            SHF_UP:
                            begin
                                operation_point_x_reg <= operation_point_x_reg;
                                operation_point_y_reg <= upper_boundary_reach_flag ? operation_point_y_reg : operation_point_y_reg - 1;
                            end
                            SHF_DOWN:
                            begin
                                operation_point_x_reg <= operation_point_x_reg;
                                operation_point_y_reg <= lower_boundary_reach_flag ? operation_point_y_reg : operation_point_y_reg + 1;
                            end
                            SHF_LEFT:
                            begin
                                operation_point_x_reg <= left_boundary_reach_flag ? operation_point_x_reg : operation_point_x_reg - 1;
                                operation_point_y_reg <= operation_point_y_reg;
                            end
                            SHF_RIGHT:
                            begin
                                operation_point_x_reg <= right_boundary_reach_flag ? operation_point_x_reg : operation_point_x_reg + 1;
                                operation_point_y_reg <= operation_point_y_reg;
                            end
                            default:
                            begin
                                operation_point_y_reg <= operation_point_y_reg;
                                operation_point_x_reg <= operation_point_x_reg;
                            end
                        endcase
                    end
                    else
                    begin
                        operation_point_y_reg <= operation_point_y_reg;
                        operation_point_x_reg <= operation_point_x_reg;
                    end
                end
                default:
                begin
                    operation_point_y_reg <= operation_point_y_reg;
                    operation_point_x_reg <= operation_point_x_reg;
                end
            endcase
        end
    end

    //AR_temp_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            AR_temp_reg <= 'd0;
        end
        else
        begin
            case(current_state)
                IDLE:
                begin
                    AR_temp_reg <= 'd0;
                end
                ARITHMETIC_WB:
                begin
                    AR_temp_reg <= AR_out;
                end
                default:
                begin
                    AR_temp_reg <= AR_temp_reg;
                end
            endcase
        end
    end

endmodule
