 MacroEditor — Documentação e Guia de Uso
================================================================

DEPENDÊNCIA OBRIGATÓRIA
------------------------
O MacroEditor é um script escrito em AutoHotkey v2.0.
Para funcionar, é necessário ter o AutoHotkey v2 instalado no
computador. Sem ele, o arquivo .ahk não abrirá.

Download oficial: https://www.autohotkey.com/


ARQUIVOS GERADOS AUTOMATICAMENTE
----------------------------------
Ao ser executado pela primeira vez, o MacroEditor cria dois
arquivos .ini na mesma pasta onde o script está localizado:

  • MacroEditor_config.ini
      Armazena as configurações do programa: atraso entre passos,
      opção de iniciar com o Windows, Always on Top, e todas as
      configurações do Clicker Simples (keybind, modo de repetição,
      intervalo, etc.).

  • MacroEditor_macros.ini
      Armazena todas as macros gravadas: nome, keybind, janela alvo,
      passos gravados, modo de repetição e tempo de espera entre ciclos.

RECOMENDAÇÃO DE PASTA
----------------------
Por criar esses arquivos .ini na mesma pasta que o script,
é fortemente recomendado colocar o MacroEditor em uma pasta
própria antes de usá-lo, por exemplo:

  C:\Programas\MacroEditor\
  ou
  D:\Programas\MacroEditor\

Dessa forma os arquivos de configuração ficam organizados
juntos e não poluem o Desktop ou outras pastas.

Se você mover o script depois de já tê-lo usado, leve os
arquivos .ini junto — caso contrário as macros e configurações
salvas serão perdidas.


================================================================
  FUNCIONALIDADES
================================================================

1. GRAVAR MACRO
----------------
Permite gravar sequências de cliques do mouse para serem
reproduzidas automaticamente depois.

  - Defina um nome para a macro.
  - Crie uma keybind (atalho de teclado) opcional para acioná-la.
  - Clique em "Iniciar gravação" e clique nas posições desejadas
    na tela. O programa grava cada clique com sua posição relativa
    à janela alvo (ou absoluta, se for o Desktop).
  - Clique em "Parar" para encerrar a gravação.
  - A janela alvo é detectada automaticamente no primeiro clique
    gravado, identificando tanto o processo (exe) quanto o título
    da janela para maior precisão.
  - Clique em "Salvar" para guardar a macro.


2. EDITAR MACRO
----------------
Selecione uma macro na lista e clique em "Editar" (ou dê
duplo clique) para:
  - Alterar o nome ou a keybind.
  - Regravar os passos do zero.
  - Modificar o modo de repetição.


3. EXCLUIR MACRO
-----------------
Selecione uma ou mais macros na lista (Ctrl+Clique ou
Shift+Clique para múltipla seleção) e clique em "Excluir".


4. EXECUTAR MACRO MANUALMENTE
-------------------------------
Selecione uma macro na lista e clique em "Executar" para
rodá-la imediatamente, sem precisar usar a keybind.


5. KEYBINDS (ATALHOS DE TECLADO)
----------------------------------
Cada macro pode ter uma keybind para ser acionada de qualquer
lugar, mesmo com outras janelas abertas.

  - O construtor de keybind permite marcar modificadores
    (Ctrl, Alt, Shift) e capturar a tecla pressionada.
  - Macros SEM repetição: executam uma vez ao pressionar.
  - Macros COM repetição: a keybind funciona como toggle —
    pressionar inicia o loop, pressionar novamente para.


6. MODOS DE REPETIÇÃO
-----------------------
Ao criar ou editar uma macro, é possível escolher como ela
se repete:

  • Sem repetir   — executa os passos uma única vez.
  • Vezes         — repete N vezes e para.
  • Minutos       — fica em loop pelo tempo definido (em minutos).
  • Cliques       — repete N vezes (equivalente a "Vezes",
                    pensado para automações baseadas em cliques).

  É possível também definir o tempo de espera entre cada ciclo
  de repetição (em milissegundos).


7. JANELA ALVO
---------------
O MacroEditor identifica a janela alvo pelo nome do processo
(exe) combinado com o título da janela no momento da gravação.

  - Ao executar, o programa localiza a janela correta, ativa-a
    e calcula as coordenadas absolutas de clique na tela com
    base na posição atual da janela — funcionando mesmo que ela
    tenha sido movida de lugar.
  - Se a janela não estiver aberta, o programa tenta abri-la
    automaticamente usando o caminho completo do executável
    que foi salvo no momento da gravação.
  - Para macros gravadas no Desktop, os cliques são em
    coordenadas absolutas de tela.


8. CLICKER SIMPLES
-------------------
Um autoclicker independente das macros, acessível pelo painel
na tela principal ou pelo ícone na bandeja do sistema.

  Configurações disponíveis:
  • Keybind        — tecla ou botão do mouse para ligar/desligar
                     (suporta botões especiais: scroll, X1, X2).
  • Modo de loop   — Infinito, por quantidade de vezes ou por minutos.
  • Intervalo      — tempo entre cada clique (em milissegundos).
  • Ativado        — checkbox na tela principal para habilitar ou
                     desabilitar o clicker sem alterar a keybind.

  A keybind do clicker funciona como toggle: pressionar inicia
  os cliques automáticos, pressionar novamente para.


9. BANDEJA DO SISTEMA (TRAY)
-----------------------------
O MacroEditor roda em segundo plano mesmo com a janela fechada.
O ícone na bandeja do sistema oferece acesso rápido a:

  • Abrir MacroEditor  — abre a janela principal.
  • Recarregar hotkeys — reaplica todas as keybinds (útil se
                         alguma parou de responder).
  • Sair               — encerra o programa completamente.

  Minimizar a janela principal também a esconde para a bandeja
  (não aparece na barra de tarefas).


10. INICIAR COM O WINDOWS
--------------------------
Nas Configurações, é possível ativar a opção de iniciar o
MacroEditor automaticamente junto com o Windows.

  - Quando ativado, é criado um atalho na pasta de Startup do
    Windows apontando para o script com o argumento /silent.
  - No modo silencioso, o programa inicia apenas na bandeja,
    sem abrir a janela principal.
  - O atalho de startup é recriado automaticamente toda vez
    que o script iniciar (enquanto a opção estiver ativa),
    garantindo que ele permaneça correto mesmo após mover
    o script de pasta.


11. CONFIGURAÇÕES GERAIS
-------------------------
Acessadas pelo botão "Configurações" na tela principal:

  • Iniciar com o Windows  — cria/remove o atalho de startup.
  • Always on Top          — mantém as janelas do MacroEditor
                             sempre visíveis sobre as demais.
  • Atraso entre passos    — tempo de espera (ms) entre cada
                             passo ao executar uma macro.
                             Padrão: 150 ms.


================================================================
  RESUMO RÁPIDO DE USO
================================================================

  1. Coloque o MacroEditor.ahk em uma pasta própria.
  2. Instale o AutoHotkey v2 se ainda não tiver.
  3. Execute o MacroEditor.ahk com duplo clique.
  4. Clique em "Gravar Macro", dê um nome e uma keybind.
  5. Clique em "Iniciar gravação" e clique nas posições desejadas.
  6. Clique em "Parar" e depois "Salvar".
  7. Use a keybind configurada para acionar a macro a qualquer momento.
  8. O programa fica rodando na bandeja — fechar a janela não encerra o programa.

================================================================
