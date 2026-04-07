-- ============================================================
--  Projeto: Vitrine Financeira + Assistente IA (Gemini [yeBOT])
-- ============================================================

CREATE DATABASE IF NOT EXISTS yeezus
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE yeezus;

-- ============================================================
-- 1. USUARIO
-- ============================================================
CREATE TABLE usuario (
    id            bigint          NOT NULL AUTO_INCREMENT,
    nome          VARCHAR(150)    NOT NULL,
    email         VARCHAR(255)    NOT NULL UNIQUE,
    senha_hash    VARCHAR(255)    NOT NULL,   -- bcrypt / Argon2
    data_criacao  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ativo         tinyint(1)      NOT NULL DEFAULT 1,

    PRIMARY KEY (id),
    INDEX idx_usuario_email (email)
) ENGINE=InnoDB;

-- ============================================================
-- 2. CONEXAO_BANCARIA
--    Representa cada banco/corretora conectada pelo usuário.
--    token_leitura deve ser armazenado criptografado na aplicação
--    antes de persistir aqui.
-- ============================================================
CREATE TABLE conexao_bancaria (
    id                BIGINT          NOT NULL AUTO_INCREMENT,
    usuario_id        BIGINT          NOT NULL,
    nome_instituicao  VARCHAR(100)    NOT NULL,          -- ex: "Nubank", "XP Investimentos"
    tipo_instituicao  ENUM('BANCO','CORRETORA','CARTAO') NOT NULL DEFAULT 'BANCO',
    status_conexao    ENUM('ATIVA','EXPIRADA','ERRO')    NOT NULL DEFAULT 'ATIVA',
    token_leitura     TEXT,                              -- Criptografado pela aplicação python
    ultima_sync       DATETIME,                         -- Última sincronização bem-sucedida
    data_criacao      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    INDEX idx_conexao_usuario (usuario_id),
    CONSTRAINT fk_conexao_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 3. TRANSACAO
--    Histórico de entradas e saídas lidas das contas.
--    A coluna categoria pode ser preenchida/corrigida pela IA.
-- ============================================================
CREATE TABLE transacao (
    id                BIGINT          NOT NULL AUTO_INCREMENT,
    conexao_id        BIGINT          NOT NULL,
    data_transacao    DATE            NOT NULL,
    valor             DECIMAL(15,2)   NOT NULL,          -- Positivo = receita, negativo = despesa
    tipo              ENUM('RECEITA','DESPESA')  NOT NULL,
    categoria         VARCHAR(80),                       -- Alimentação, Transporte, Lazer …
    descricao         VARCHAR(255),
    id_externo        VARCHAR(100),                      -- ID da transação no banco de origem
    data_importacao   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    INDEX idx_transacao_conexao   (conexao_id),
    INDEX idx_transacao_data      (data_transacao),
    INDEX idx_transacao_categoria (categoria),
    UNIQUE KEY uq_transacao_externa (conexao_id, id_externo),
    CONSTRAINT fk_transacao_conexao
        FOREIGN KEY (conexao_id) REFERENCES conexao_bancaria(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 4. INVESTIMENTO
--    Carteira de ativos do usuário.
-- ============================================================
CREATE TABLE investimento (
    id               BIGINT          NOT NULL AUTO_INCREMENT,
    usuario_id       BIGINT          NOT NULL,
    tipo_ativo       ENUM('ACAO','FII','ETF','RENDA_FIXA','CRIPTO','OUTRO') NOT NULL,
    codigo_ativo     VARCHAR(20)     NOT NULL,           -- ex: PETR4, MXRF11, "Tesouro Selic 2029"
    quantidade       DECIMAL(18,8)   NOT NULL DEFAULT 0, -- Suporta frações (cripto, cotas)
    preco_medio      DECIMAL(15,6)   NOT NULL DEFAULT 0, -- Preço médio de compra
    valor_atualizado DECIMAL(15,2),                      -- Atualizado pelo scheduler via API de mercado
    data_atualizacao DATETIME,                           -- Quando valor_atualizado foi obtido
    data_criacao     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    INDEX idx_investimento_usuario (usuario_id),
    INDEX idx_investimento_codigo  (codigo_ativo),
    CONSTRAINT fk_investimento_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 5. HISTORICO_CHAT_IA
--    Mantém o contexto das conversas com o Gemini.
--    O backend python monta o histórico e envia à API.
-- ============================================================
CREATE TABLE historico_chat_ia (
    id                   BIGINT       NOT NULL AUTO_INCREMENT,
    usuario_id           BIGINT       NOT NULL,
    sessao_id            VARCHAR(64)  NOT NULL,    -- UUID gerado por sessão de conversa
    mensagem_usuario     TEXT         NOT NULL,
    resposta_assistente  TEXT         NOT NULL,
    tokens_utilizados    INT,                      -- Para monitorar consumo da API Gemini
    data_hora            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    INDEX idx_chat_usuario (usuario_id),
    INDEX idx_chat_sessao  (sessao_id),
    INDEX idx_chat_data    (data_hora),
    CONSTRAINT fk_chat_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 6. VIEW AUXILIAR — resumo_mensal_usuario
--    Facilita a montagem do contexto enviado à IA:
--    "Quanto gastei em Alimentação em março/2025?"
-- ============================================================
CREATE OR REPLACE VIEW resumo_mensal_usuario AS
SELECT
    cb.usuario_id,
    YEAR(t.data_transacao)  AS ano,
    MONTH(t.data_transacao) AS mes,
    t.tipo,
    t.categoria,
    COUNT(*)                AS qtd_transacoes,
    SUM(t.valor)            AS total_valor
FROM transacao t
JOIN conexao_bancaria cb ON cb.id = t.conexao_id
GROUP BY
    cb.usuario_id,
    YEAR(t.data_transacao),
    MONTH(t.data_transacao),
    t.tipo,
    t.categoria;

-- ============================================================
-- 7. VIEW AUXILIAR — patrimonio_usuario
--    Soma rápida do valor atual da carteira por tipo de ativo.
-- ============================================================
CREATE OR REPLACE VIEW patrimonio_usuario AS
SELECT
    usuario_id,
    tipo_ativo,
    COUNT(*)                  AS qtd_ativos,
    SUM(quantidade * preco_medio)   AS custo_total,
    SUM(valor_atualizado)     AS valor_mercado_total
FROM investimento
GROUP BY usuario_id, tipo_ativo;

-- ============================================================
-- FIM DO SCRIPT
-- ============================================================