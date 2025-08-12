module safecrackpro_v2_fsm (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] btn,        // Entradas dos botões (BTN[3:0])
    output logic       unlocked    // Saída: 1 quando o cofre está desbloqueado
);

    // one-hot encoding para 7 estados
    typedef enum logic [6:0] {
        S0 = 7'b0000001,  // Estado inicial
        S1 = 7'b0000010,  // Código 1 OK
        S2 = 7'b0000100,  // Código 2 OK
        S3 = 7'b0001000,  // Desbloqueado
        PROG_S0 = 7'b0010000, // Programando senha parte 1
        PROG_S1 = 7'b0100000, // Programando senha parte 2
        PROG_S2 = 7'b1000000  // Programando senha parte 3
    } state_t;

    state_t state, next;

    // A senha agora é ser modificável
    logic [3:0] passcode[2:0];

    // Lógica Sequencial
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S0;
            // Senha inicial padrão ao resetar
            passcode[0] <= 4'b0111;
            passcode[1] <= 4'b1101;
            passcode[2] <= 4'b1101;
        end
        else begin
            // Atualiza o estado no pulso de clock
            state <= next;

            // Lógica de programação da nova senha
            // A escrita só acontece no pulso de clock, garantindo estabilidade
            case (state)
                PROG_S0: if (|btn) passcode[0] <= btn;
                PROG_S1: if (|btn) passcode[1] <= btn;
                PROG_S2: if (|btn) passcode[2] <= btn;
                default:; // não faz nada nos outros estados
            endcase
        end
    end

    // Lógica Combinacional
    always_comb begin
        next = state; // Por padrão, mantém o estado atual se nada acontecer
        case (state)
            S0: if (btn == passcode[0]) next = S1;
                else if (|btn) next = S0; // Se errar, permanece em S0

            S1: if (btn == passcode[1]) next = S2;
                else if (|btn) next = S0; // Se errar, volta para o início

            S2: if (btn == passcode[2]) next = S3;
                else if (|btn) next = S0; // Se errar, volta para o início

            // No estado desbloqueado, se BTN0 for pressionado, entra em modo de programação
            S3: if (btn == 4'b0001) next = PROG_S0;
                else next = S3; // Senão, permanece desbloqueado

            // Lógica para o modo de programação
            PROG_S0: if (|btn) next = PROG_S1; // Qualquer botão pressionado avança
            PROG_S1: if (|btn) next = PROG_S2;
            PROG_S2: if (|btn) next = S0;      // Após o último, salva e volta ao início

            default: next = S0;
        endcase
    end

    // Lógica de Saída
    always_comb begin
        unlocked = (state == S3);
    end

endmodule
