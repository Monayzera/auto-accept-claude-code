# auto-accept

Plugin para o Claude Code que responde os prompts de permissão com **Permitir (uma vez)**. Você continua no modo **Manual**, e o plugin clica em Permitir por você.

Feito para o Claude Code Desktop no Windows. Também funciona no Claude Code CLI da mesma máquina, porque os dois leem as mesmas configurações de plugin.

[Read in English](README.md)

## Por quê

`"permissions": { "allow": ["*"] }` não funciona. O Claude Code ignora um glob solto como `"*"` (mostra um aviso), então nada é aprovado. Este plugin usa o hook oficial `PermissionRequest`. Ele roda no momento em que o Claude Code iria mostrar o diálogo de permissão e devolve a mesma decisão de clicar em Permitir uma vez.

## Instalação

**Opção 1: um comando no PowerShell**

```powershell
irm https://raw.githubusercontent.com/Monayzera/auto-accept-claude-code/main/install.ps1 | iex
```

O script acha o Claude Code mais novo da máquina (CLI no PATH ou a cópia que vem com o Desktop), adiciona o marketplace e instala o plugin no escopo de usuário.

**Opção 2: dentro do Claude Code**

```
/plugin marketplace add Monayzera/auto-accept-claude-code
/plugin install auto-accept@monayzera-plugins
```

Depois de instalar, abra uma sessão nova ou rode `/reload-plugins` numa sessão aberta. Deixe o modo de permissão em **Manual**.

## Uso

| Comando | Efeito |
| --- | --- |
| `/auto-accept on` | Liga o auto-accept (padrão após instalar) |
| `/auto-accept off` | Desliga; os prompts aparecem normalmente |
| `/auto-accept status` | Mostra o estado, o caminho do log e as últimas 10 aprovações |

O estado ligado/desligado fica salvo na pasta de dados do plugin. Por isso vale para todas as sessões e sobrevive a reinícios e atualizações. O próprio Claude não consegue rodar esse comando.

## O que ele aprova

| Situação | Comportamento |
| --- | --- |
| Prompt de permissão no modo Manual (`default`) ou Plan | Permitir (uma vez) |
| `AskUserQuestion` e `ExitPlanMode` | Nunca responde; você vê normalmente |
| Outros modos (acceptEdits, auto, bypassPermissions, ...) | Não interfere |
| Plugin desligado | Não interfere |
| Qualquer erro interno (entrada inválida, estado ilegível) | Não interfere; o diálogo normal aparece |

Permitir (uma vez) não grava regras nos seus settings. Desligou o plugin, todos os prompts voltam.

## Limites

Estes limites vêm do próprio Claude Code, e nenhum hook consegue mudá-los:

- Suas regras `deny` e `ask` continuam valendo acima do hook.
- Ferramentas MCP que exigem interação do usuário sempre pedem.
- O `/auto-accept` roda pela ferramenta PowerShell, que vem ligada por padrão no Windows. Se você desligou com `CLAUDE_CODE_USE_POWERSHELL_TOOL=0`, o comando não funciona. O hook continua funcionando.

Testado no Claude Code 2.1.295 (Windows 11): o hook aprova Bash, Write e escritas na pasta protegida `.claude`, e depois de `/auto-accept off` o prompt volta a aparecer.

## Log

Cada aprovação automática vira uma linha em `approvals.log`, na pasta de dados do plugin: horário, sessão, modo, ferramenta e um resumo curto do comando ou arquivo. Ao chegar em 1 MB, o log é rotacionado para `approvals.log.1`. `/auto-accept status` mostra o caminho.

## Como funciona

```
hooks/hooks.json          hook PermissionRequest, matcher "*"
scripts/run.cmd           roda approve.js com Node se instalado, senão approve.ps1
scripts/approve.js        lógica de decisão (Node)
scripts/approve.ps1       mesma lógica (Windows PowerShell, sem dependências)
scripts/toggle.ps1        on / off / status
skills/auto-accept/       o comando /auto-accept
```

O Node.js é opcional. Sem ele, entra o handler em PowerShell, que adiciona cerca de 0,3 s por prompt.

## Desinstalar

```powershell
irm https://raw.githubusercontent.com/Monayzera/auto-accept-claude-code/main/uninstall.ps1 | iex
```

Ou dentro do Claude Code: `/plugin uninstall auto-accept@monayzera-plugins`.

## Aviso

Com o auto-accept ligado, qualquer comando que o Claude decidir rodar é aprovado sem você ver. Isso inclui comandos sugeridos por uma página web ou arquivo que o Claude leu. Use `/auto-accept off` ao trabalhar com conteúdo não confiável e confira o log.

## Licença

MIT
