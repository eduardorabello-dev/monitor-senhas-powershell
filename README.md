# Monitor de Expiração de Senhas (PowerShell)

Script em PowerShell que automatiza o acompanhamento da expiração de senhas de usuários de domínio Windows. Ele lê uma planilha de usuários, consulta a data de expiração de cada senha e gera um relatório no terminal, classificando cada conta por urgência.

Nasceu de uma necessidade real do dia a dia de suporte técnico: descobrir antes quais usuários estavam prestes a ficar sem acesso, em vez de esperar o chamado chegar.

## O que ele faz

1. Lê um CSV (separador `;`) com a lista de usuários.
2. Para cada usuário, executa `net user <usuario> /domain` e extrai a data de expiração (funciona com Windows em português e em inglês).
3. Calcula quantos dias faltam e classifica a senha:

| Status | Critério |
|---|---|
| `EXPIRADA` | já expirou |
| `CRITICA` | expira em até 7 dias |
| `ATENCAO` | expira em até 15 dias |
| `OK` | mais de 15 dias |
| `ERRO` | usuário não encontrado ou consulta sem resultado |

4. Atualiza o próprio CSV com as colunas `DATA DE EXPIRACAO` e `UltimaConsulta`.
5. Exibe um relatório colorido, ordenado por dias restantes, com um resumo no final.

## Decisões técnicas

- **Backup antes de alterar o CSV:** toda execução cria uma cópia com data e hora na pasta de backup.
- **Gravação segura:** o CSV é escrito primeiro em um arquivo temporário e só depois substitui o original, o que evita corromper a planilha se algo falhar (por exemplo, arquivo aberto no Excel).
- **Sem dependências extras:** usa apenas comandos nativos do Windows e do PowerShell.
- **Configurável:** caminho do arquivo, pasta de backup e nome da coluna de usuário são parâmetros, e os limites de dias ficam no topo do script.

## Como usar

Requisitos: Windows, PowerShell e uma máquina com acesso ao domínio.

1. Monte um CSV como o de [`usuarios-exemplo.csv`](usuarios-exemplo.csv), com o login de cada usuário na coluna `USUARIO`.
2. Execute:

```powershell
.\monitor-expiracao-senhas.ps1 -Arquivo .\usuarios.csv
```

Parâmetros opcionais:

```powershell
.\monitor-expiracao-senhas.ps1 -Arquivo .\usuarios.csv -PastaBackup .\Backup -ColunaUsuario USUARIO
```

## Próximos passos

- Exportar o relatório para um arquivo.
- Enviar alerta por e-mail para os usuários em estado crítico.
- Agendar a execução automática (Agendador de Tarefas).

## Autor

Eduardo Rabello: estudante de Análise e Desenvolvimento de Sistemas (USF).
[LinkedIn](https://www.linkedin.com/in/eduardo-rabello07/)
