module sc (
    input  logic       clk,         // Clock do sistema (100 MHz na DE2-115)
    input  logic       rst,         // Reset assíncrono ativo-alto
    input  logic [3:0] btn,         // Entradas dos botões (BTN[3:0])
    output logic       unlocked,    // Saída: 1 quando o cofre está desbloqueado
    output logic       lock_led,      // LED vermelho indica bloqueio ativo
    output logic       unlocked_led
);

    // one-hot encoding para 7 estados
    typedef enum logic [6:0] {
        S0      = 7'b0000001,  // Estado inicial
        S1      = 7'b0000010,  // Código 1 OK
        S2      = 7'b0000100,  // Código 2 OK
        S3      = 7'b0001000,  // Desbloqueado
        PROG_S0 = 7'b0010000,  // Programando senha parte 1
        PROG_S1 = 7'b0100000,  // Programando senha parte 2
        PROG_S2 = 7'b1000000   // Programando senha parte 3
    } state_t;

    state_t state, next;

    // Senha programável
    logic [3:0] passcode[2:0];

    // Contadores e flags
    logic [1:0]  error_count;       // Conta erros (0 a 3)
    logic        locked;            // Flag de bloqueio ativo
    logic [31:0] timeout_counter;   // Contador para 10 segundos

    localparam int TIMEOUT_MAX = 500_000_000; // 100 MHz * 10 s

    // BLOCO PRINCIPAL SEQUENCIAL
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset geral
            state <= S0;
            passcode[0] <= 4'b1011; // KEY2
            passcode[1] <= 4'b1101; // KEY1
            passcode[2] <= 4'b1110; // KEY0
            error_count <= 0;
            locked <= 0;
            timeout_counter <= 0;
        end
        else begin
            if (locked) begin
                if (timeout_counter < TIMEOUT_MAX) begin
                    timeout_counter <= timeout_counter + 1;
                end
                else begin
                    locked <= 0;
                    timeout_counter <= 0;
                    error_count <= 0;
                    state <= S0;
                end
            end
            else begin
                state <= next;

                case (state)
                    PROG_S0: if (|btn) passcode[0] <= btn;
                    PROG_S1: if (|btn) passcode[1] <= btn;
                    PROG_S2: if (|btn) passcode[2] <= btn;
                    default: ;
                endcase

                // *** MUDANÇA DEFINITIVA AQUI ***
                // Condição de erro "paciente", ignorando o estado de botões soltos
                if ((state == S0 && btn != 4'b1111 && btn != passcode[0]) ||
                    (state == S1 && btn != 4'b1111 && btn != passcode[1]) ||
                    (state == S2 && btn != 4'b1111 && btn != passcode[2])) begin
                    if (error_count < 2)
                        error_count <= error_count + 1;
                    else begin
                        locked <= 1;
                        timeout_counter <= 0;
                    end
                end
                // Lógica para zerar os erros (já estava correta)
                else if ((state == S0 && btn == passcode[0]) ||
                         (state == S1 && btn == passcode[1]) ||
                         (state == S2 && btn == passcode[2])) begin
                    error_count <= 0;
                end
            end
        end
    end

    // Lógica Combinacional FSM (já estava correta)
    always_comb begin
        next = state;
        if (!locked) begin
            case (state)
                S0: begin
                    if (btn == passcode[0]) next = S1;
                    else if (btn != 4'b1111) next = S0;
                end
                S1: begin
                    if (btn == passcode[1]) next = S2;
                    else if (btn != 4'b1111) next = S0;
                end
                S2: begin
                    if (btn == passcode[2]) next = S3;
                    else if (btn != 4'b1111) next = S0;
                end
                S3: begin
                    if (btn == 4'b0111) next = PROG_S0; // Pressionar KEY3
                    else next = S3;
                end
                PROG_S0: if (|btn) next = PROG_S1;
                PROG_S1: if (|btn) next = PROG_S2;
                PROG_S2: if (|btn) next = S0;
                default: next = S0;
            endcase
        end
    end

    // Saídas (sem alterações)
    always_comb begin
        logic correct_digit_flash;
        unlocked = (state == S3);
        lock_led = locked;
        correct_digit_flash = (state == S0 && btn == passcode[0]) ||
                              (state == S1 && btn == passcode[1]) ||
                              (state == S2 && btn == passcode[2]);
        unlocked_led = correct_digit_flash || unlocked;
    end

endmodule
