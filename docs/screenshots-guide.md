# App Store Screenshots Guide

## Sizes accepted (escolha 1 e tire **todas** nesse tamanho)

- **2880 x 1800** ← preferido (retina 16:10)
- 2560 x 1600
- 1440 x 900
- 1280 x 800

Mínimo: **1 screenshot**, recomendado **3-5**, máximo **10**.

## Recommended set (3 shots ordering)

### Shot 1 — Dashboard com stats cheias (hero)
A tela principal mostrando heatmap anual, sequência, metas, e horários de foco. Esse é o screenshot que vende o app.

**Como capturar:**
1. Abre StatFocus → ícone do dashboard (chart.bar)
2. Vai em Configurações → Desenvolvimento → "Gerar dados de teste (60 dias)" — popula stats fake pra screenshot ficar bonita
3. Volta pra aba Estatísticas
4. Espera todas as animações terminarem (uns 2s)
5. ⇧⌘4 → barra de espaço → clica na janela → salva PNG

### Shot 2 — Timer panel flutuante
O cronômetro Pomodoro em foco, com botões visíveis.

**Como capturar:**
1. Mostra timer (⇧⌘F se estiver oculto)
2. Aperta Play
3. Deixa rodar uns 5s pra mostrar 24:55 ou parecido
4. ⇧⌘4 → barra de espaço → clica no timer panel

### Shot 3 — Configurações simples
Pra mostrar simplicidade. Aba Configurações com seção Timer + Metas visível.

**Como capturar:**
1. Dashboard → Configurações
2. Rola pro topo (Timer + Metas + Geral)
3. ⇧⌘4 → barra de espaço → clica na janela

### (Opcional) Shot 4 — Gráfico de horários
Foca no novo Horários de Foco. Útil pra mostrar feature diferente.

### (Opcional) Shot 5 — Heatmap anual de perto
Foca no heatmap GitHub-style.

## Redimensionando pra 2880x1800

Sua tela é 3440x1440, então screenshots brutos não batem direto. Duas opções:

### Opção A — Centralizar em canvas branco/colorido (mais bonito)
1. Abre Preview ou Pixelmator ou Figma
2. Cria canvas 2880x1800
3. Cola o screenshot no centro
4. Fundo: branco, ou um verde claro tipo `#E8F0EC` que combina com o accent do app
5. Exporta PNG

### Opção B — Capturar área 2880x1800 da tela
1. ⇧⌘4 → arrasta área aproximada (~30% da tela ultrawide)
2. Abre Preview, Tools → Adjust Size → 2880x1800 exato (proportional unchecked se necessário)
3. Salva

Eu recomendo **Opção A** — fica muito mais profissional na App Store. Posso te ajudar com um template em HTML/Figma se quiser.

## Onde salvar

Salva em `docs/screenshots/` neste repo:
```
docs/screenshots/01-dashboard.png
docs/screenshots/02-timer.png
docs/screenshots/03-settings.png
```

## Upload em App Store Connect

App Store Connect → My Apps → StatFocus → versão → "App Information" / "macOS App Store" → arrastar PNGs em "macOS Screenshots" → Save.
