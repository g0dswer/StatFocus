# StatFocus — Design Document
**Data:** 2026-02-20
**Status:** Aprovado

---

## Visão Geral

**StatFocus** é um app macOS nativo (Swift + SwiftUI) de timer Pomodoro com foco em **visualização estatística do tempo de estudo**. Inspirado visualmente no app Flow, diferencia-se pelo conjunto robusto de métricas: heatmap anual, metas com progresso e streak de dias consecutivos.

---

## Problema

O Flow e apps similares registram o tempo, mas oferecem estatísticas superficiais (só gráfico de barras semanal). Estudantes que querem entender seus padrões de longo prazo não têm visibilidade sobre consistência, tendências ou cumprimento de metas.

---

## Solução

App macOS com:
- Timer Pomodoro com janela flutuante always-on-top (igual ao Flow)
- Dashboard estatístico rico com heatmap, metas e streak
- Experiência simples: um clique para iniciar, estatísticas automáticas

---

## Arquitetura

### Tecnologia
- **Swift + SwiftUI** — app nativo macOS
- **SwiftData** (ou CoreData) — persistência local de sessões
- **AppKit NSPanel** — janela flutuante always-on-top, sem aparecer no Dock

### Estrutura de Telas

```
StatFocus.app
├── TimerWindow (NSPanel flutuante, always-on-top)
│   ├── Timer display (MM:SS grande)
│   ├── Indicadores de ciclo (● ● ● ●)
│   ├── Botão Play/Pause/Stop
│   └── Botão → abrir Dashboard
│
└── DashboardWindow (janela principal)
    ├── Tab: Estatísticas
    │   ├── Heatmap anual (tipo GitHub)
    │   ├── Streak atual + recorde
    │   ├── Meta diária/semanal com barra de progresso
    │   └── Gráfico de barras D/S/M/A
    └── Tab: Configurações
        ├── Duração do Flow (padrão 25 min)
        ├── Duração da pausa curta (5 min)
        ├── Duração da pausa longa (15 min)
        ├── Ciclos até pausa longa (padrão 4)
        ├── Meta diária de horas
        ├── Meta semanal de horas
        ├── Iniciar no login
        └── Notificações (som ao concluir)
```

---

## Modelo de Dados

```swift
// Sessão de estudo completada
struct StudySession {
    id: UUID
    startedAt: Date
    duration: TimeInterval   // segundos de foco efetivo
    type: SessionType        // .focus | .shortBreak | .longBreak
}

// Configurações do usuário
struct AppSettings {
    focusDuration: Int       // minutos (padrão 25)
    shortBreakDuration: Int  // minutos (padrão 5)
    longBreakDuration: Int   // minutos (padrão 15)
    cyclesBeforeLongBreak: Int  // padrão 4
    dailyGoalHours: Double   // padrão 4.0
    weeklyGoalHours: Double  // padrão 20.0
    launchAtLogin: Bool
    soundEnabled: Bool
}
```

---

## Funcionalidades por Tela

### Timer Window (flutuante)
- Timer grande no centro (MM:SS)
- 4 pontinhos indicando ciclos (● = completo, ○ = pendente)
- Play → inicia contagem regressiva
- Pause → pausa o timer
- Stop → finaliza sessão atual e salva no banco
- Ícone de gráfico → abre Dashboard
- Transição automática Focus → Pausa com notificação sonora

### Dashboard — Estatísticas
- **Heatmap anual**: grid 52×7, cor proporcional às horas estudadas naquele dia (escala verde, igual GitHub). Hover mostra data + horas.
- **Streak**: "🔥 7 dias seguidos" com recorde histórico abaixo
- **Meta diária**: barra de progresso circular (ex: 2h 30min / 4h = 62%)
- **Meta semanal**: barra linear (ex: 12h / 20h = 60%)
- **Gráfico de barras**: tabs D/S/M/A — mostra horas por período (igual ao Flow mas mais detalhado)

### Dashboard — Configurações
- Sliders/Steppers para duração dos timers
- Toggle launchAtLogin (usando ServiceManagement)
- Campos numéricos para metas de horas
- Toggle para som de notificação

---

## UX / Visual

- **Paleta**: branco/cinza claro + verde escuro (#2D6A4F) como cor de acento — igual ao Flow
- **Tipografia**: SF Pro (sistema macOS)
- **Janela flutuante**: bordas arredondadas, sem barra de título, semitransparente/fosca
- **Animações**: timer com countdown suave, transição de estados
- **Sem conta, sem cloud**: 100% local, zero fricção para começar

---

## Fora do Escopo (v1)
- Categorias/tags por sessão
- Sincronização entre dispositivos
- Widget de menu bar
- Bloqueador de apps/sites
- Exportação de dados

---

## Critérios de Sucesso
1. Timer Pomodoro funciona corretamente com ciclos configuráveis
2. Sessões são salvas automaticamente ao completar ou ao parar
3. Heatmap renderiza corretamente com dados históricos
4. Streak calcula dias consecutivos corretamente
5. Metas mostram progresso em tempo real durante sessão ativa
6. Janela flutuante permanece sobre todos os apps
