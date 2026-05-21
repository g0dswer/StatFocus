// StatFocus/Models/LocalizationManager.swift
// Runtime language switching backed by an in-memory string catalog.
// SwiftUI auto-tracks reads via @Observable, so views re-render on toggle.
import Foundation
import Observation

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    enum Language: String, CaseIterable, Identifiable {
        case pt = "pt"
        case en = "en"

        var id: String { rawValue }
        var shortLabel: String { rawValue.uppercased() }
    }

    private let defaultsKey = "app.language"

    var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: defaultsKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: defaultsKey) ?? Language.pt.rawValue
        self.currentLanguage = Language(rawValue: stored) ?? .pt
    }

    func toggle() {
        currentLanguage = (currentLanguage == .pt) ? .en : .pt
    }

    /// Returns the translated string for the current language.
    /// Falls back to PT, then to the raw key if nothing matches.
    func t(_ key: String) -> String {
        if let v = StringCatalog.entries[currentLanguage]?[key] { return v }
        if let v = StringCatalog.entries[.pt]?[key] { return v }
        return key
    }
}

/// Convenience global accessor — keeps view code terse: `L.t("key")`
enum L {
    static func t(_ key: String) -> String {
        LocalizationManager.shared.t(key)
    }
}

/// All user-facing strings. Add new entries here when introducing UI copy.
/// Keys use dot.namespace convention: `<area>.<purpose>`.
enum StringCatalog {
    static let entries: [LocalizationManager.Language: [String: String]] = [
        .pt: pt,
        .en: en
    ]

    private static let pt: [String: String] = [
        // Tabs
        "tab.stats": "Estatísticas",
        "tab.settings": "Configurações",

        // Stats — sections
        "stats.streak": "Sequência",
        "stats.streak.day_one": "dia seguido",
        "stats.streak.day_many": "dias seguidos",
        "stats.streak.record": "recorde",
        "stats.goals": "Metas",
        "stats.goals.today": "hoje",
        "stats.goals.week": "semana",
        "stats.year_activity": "Atividade do Ano",
        "stats.hourly_title": "Horários de Foco",
        "stats.hours_title": "Horas de Foco",
        "stats.legend.less": "Menos",
        "stats.legend.more": "Mais",

        // Stats — tooltips
        "stats.no_study": "sem estudo",
        "stats.no_focus": "sem foco",

        // Stats — chart periods (bar chart)
        "period.day": "Dia",
        "period.week": "Semana",
        "period.month": "Mês",
        "period.year": "Ano",

        // Stats — hourly periods
        "hourly.7d": "7d",
        "hourly.30d": "30d",
        "hourly.all": "Tudo",

        // Settings — sections + texts
        "settings.section.total_focus_active": "Foco Total Ativo",
        "settings.total_focus_lock_message": "Durante o foco, não é possível alterar configurações. A edição será liberada quando entrar na pausa.",
        "settings.section.timer": "Timer",
        "settings.timer.focus_minutes": "Foco: %d min",
        "settings.timer.break_minutes": "Pausa: %d min",
        "settings.section.goals": "Metas",
        "settings.goals.daily": "Meta diária",
        "settings.goals.weekly": "Meta semanal",
        "settings.goals.hours_unit": "horas",
        "settings.section.general": "Geral",
        "settings.general.sound": "Som de notificação",
        "settings.general.auto_hide": "Ocultar janela ao iniciar foco",
        "settings.general.total_focus": "Foco Total",
        "settings.general.total_focus_help": "Foco Total impede pausar a sessão de foco, ocultar o timer e mudar configurações até entrar na pausa.",
        "settings.general.auto_show_help": "Quando ativado, o timer reaparece automaticamente 30 segundos antes do foco acabar.",
        "settings.general.start_at_login": "Iniciar no login",
        "settings.section.notifications": "Notificações do macOS",
        "settings.notifications.help1": "Ao iniciar foco, o StatFocus tenta ativar Não Perturbe. Ao entrar na pausa (ou pausar foco normal), ele desativa.",
        "settings.notifications.help2": "Se o bloqueio automático não funcionar no seu macOS, crie no app Atalhos: 'StatFocus - Notificacoes OFF' e 'StatFocus - Notificacoes ON', configurando o Foco Não Perturbe ligado/desligado.",
        "settings.section.blocker": "Bloqueador",
        "settings.blocker.enable": "Ativar bloqueador durante foco",
        "settings.blocker.strictness": "Modo de bloqueio",
        "settings.blocker.strictness.strict": "Rígido",
        "settings.blocker.strictness.soft": "Amigável",
        "settings.blocker.strictness.help": "Rígido força o app/site permitido. Amigável só mostra um aviso e não bloqueia. Foco Total sempre usa rígido.",
        "settings.blocker.mode": "Modo",
        "settings.blocker.mode.app": "App",
        "settings.blocker.mode.website": "Website",
        "settings.blocker.allowed_app": "App permitido",
        "settings.blocker.allowed_app.none": "Nenhum",
        "settings.blocker.select_app": "Selecionar app permitido",
        "settings.blocker.allowed_website": "Website permitido",
        "settings.blocker.website_placeholder": "ex: youtube.com",
        "settings.blocker.browser": "Navegador",
        "settings.blocker.help": "Durante foco, só o app/site permitido pode ficar ativo. O StatFocus continua liberado para controle.",
        "settings.section.data": "Dados",
        "settings.data.help": "Apaga todas as sessões salvas e zera as métricas.",
        "settings.data.clear": "Zerar métricas / Limpar dados",
        "settings.data.clear_alert.title": "Limpar dados",
        "settings.data.clear_alert.message": "Você realmente quer limpar seus dados?",
        "settings.data.clear_alert.cancel": "Cancelar",
        "settings.data.clear_alert.confirm": "Sim, limpar",
        "settings.section.backup": "Backup",
        "settings.backup.help": "Backup salva apenas sessões e métricas para restaurar em outro computador.",
        "settings.backup.auto": "Backup automático",
        "settings.backup.folder": "Pasta",
        "settings.backup.folder.none": "Não selecionada",
        "settings.backup.choose_folder": "Escolher pasta",
        "settings.backup.now": "Backup agora",
        "settings.backup.import": "Importar backup",
        "settings.backup.last": "Último backup: %@",
        "settings.section.dev": "Desenvolvimento",
        "settings.dev.seed": "Gerar dados de teste (60 dias)",
        "settings.app_picker.title": "Escolha o app permitido durante foco",
        "settings.app_picker.prompt": "Selecionar app",

        // Backup messages (BackupManager statusMessage)
        "backup.status.auto_disabled": "Backup automático desativado.",
        "backup.status.no_folder": "Backup automático não ativado: pasta não selecionada.",
        "backup.status.auto_enabled": "Backup automático ativado.",
        "backup.status.folder_set": "Pasta de backup configurada.",
        "backup.status.saved": "Backup salvo em %@.",
        "backup.status.imported": "Backup importado: %d sessões restauradas.",
        "backup.status.auto_failed": "Falha no backup automático: %@",
        "backup.errors.no_folder": "Selecione uma pasta para salvar o backup.",
        "backup.errors.invalid_file": "Arquivo de backup inválido.",
        "backup.errors.cannot_create": "Não foi possível preparar a pasta de backup.",
        "backup.errors.cannot_write": "Não foi possível salvar o arquivo de backup.",
        "backup.errors.cannot_read": "Não foi possível ler o arquivo de backup.",

        // Timer
        "timer.phase.focus": "StatFocus",
        "timer.phase.break": "Pausa",
        "timer.help.lock_close": "Foco Total ativo: timer não pode ser ocultado",
        "timer.help.lock_pause": "Foco Total ativo: pausa desativada",
        "timer.help.reset": "Zerar contagem",
        "timer.help.skip_break": "Pular pausa",
        "timer.menu.focus_duration": "Duração do foco",
        "timer.menu.break_duration": "Duração da pausa",
        "timer.menu.daily_goal": "Meta diária",
        "timer.menu.weekly_goal": "Meta semanal",
        "timer.menu.sound": "Som de notificação",
        "timer.menu.auto_hide": "Ocultar ao iniciar foco",
        "timer.menu.total_focus": "Foco Total",
        "timer.menu.open_settings": "Abrir configurações",
        "timer.menu.hide_timer": "Ocultar timer",

        // AppDelegate notification setup alert
        "alert.notif_setup.title": "Configurar bloqueio de notificações",
        "alert.notif_setup.message": "Para bloquear notificações durante o foco, o app tenta ativar o Não Perturbe automaticamente.\nSe falhar no seu macOS, crie estes atalhos no app Atalhos:\n1) StatFocus - Notificacoes OFF\n2) StatFocus - Notificacoes ON\nEm cada um, use a ação de ajustar o Foco 'Não Perturbe' para ligado/desligado.",
        "alert.notif_setup.open_shortcuts": "Abrir Atalhos",
        "alert.notif_setup.later": "Depois",

        // Language toggle button accessibility
        "lang.toggle.help": "Alternar idioma",

        // Soft blocker banner
        "blocker.soft.title": "Foco ativo",
        "blocker.soft.message": "Você abriu %@",
    ]

    private static let en: [String: String] = [
        // Tabs
        "tab.stats": "Stats",
        "tab.settings": "Settings",

        // Stats — sections
        "stats.streak": "Streak",
        "stats.streak.day_one": "day in a row",
        "stats.streak.day_many": "days in a row",
        "stats.streak.record": "record",
        "stats.goals": "Goals",
        "stats.goals.today": "today",
        "stats.goals.week": "week",
        "stats.year_activity": "Year Activity",
        "stats.hourly_title": "Focus by Hour",
        "stats.hours_title": "Focus Hours",
        "stats.legend.less": "Less",
        "stats.legend.more": "More",

        // Stats — tooltips
        "stats.no_study": "no study",
        "stats.no_focus": "no focus",

        // Stats — chart periods (bar chart)
        "period.day": "Day",
        "period.week": "Week",
        "period.month": "Month",
        "period.year": "Year",

        // Stats — hourly periods
        "hourly.7d": "7d",
        "hourly.30d": "30d",
        "hourly.all": "All",

        // Settings — sections + texts
        "settings.section.total_focus_active": "Total Focus Active",
        "settings.total_focus_lock_message": "While focusing, you can't change settings. Editing will be unlocked when you enter the break.",
        "settings.section.timer": "Timer",
        "settings.timer.focus_minutes": "Focus: %d min",
        "settings.timer.break_minutes": "Break: %d min",
        "settings.section.goals": "Goals",
        "settings.goals.daily": "Daily goal",
        "settings.goals.weekly": "Weekly goal",
        "settings.goals.hours_unit": "hours",
        "settings.section.general": "General",
        "settings.general.sound": "Notification sound",
        "settings.general.auto_hide": "Hide window when focus starts",
        "settings.general.total_focus": "Total Focus",
        "settings.general.total_focus_help": "Total Focus prevents pausing the focus session, hiding the timer, and changing settings until the break starts.",
        "settings.general.auto_show_help": "When enabled, the timer automatically reappears 30 seconds before focus ends.",
        "settings.general.start_at_login": "Start at login",
        "settings.section.notifications": "macOS Notifications",
        "settings.notifications.help1": "When focus starts, StatFocus tries to enable Do Not Disturb. When the break starts (or focus is paused), it disables it.",
        "settings.notifications.help2": "If automatic blocking doesn't work on your macOS, create shortcuts in the Shortcuts app: 'StatFocus - Notificacoes OFF' and 'StatFocus - Notificacoes ON', configuring the Do Not Disturb Focus on/off.",
        "settings.section.blocker": "Blocker",
        "settings.blocker.enable": "Enable blocker during focus",
        "settings.blocker.strictness": "Blocking mode",
        "settings.blocker.strictness.strict": "Strict",
        "settings.blocker.strictness.soft": "Friendly",
        "settings.blocker.strictness.help": "Strict forces the allowed app/site. Friendly only shows a notice and doesn't block. Total Focus always uses strict.",
        "settings.blocker.mode": "Mode",
        "settings.blocker.mode.app": "App",
        "settings.blocker.mode.website": "Website",
        "settings.blocker.allowed_app": "Allowed app",
        "settings.blocker.allowed_app.none": "None",
        "settings.blocker.select_app": "Select allowed app",
        "settings.blocker.allowed_website": "Allowed website",
        "settings.blocker.website_placeholder": "e.g. youtube.com",
        "settings.blocker.browser": "Browser",
        "settings.blocker.help": "During focus, only the allowed app/site can stay active. StatFocus itself stays allowed for control.",
        "settings.section.data": "Data",
        "settings.data.help": "Deletes all saved sessions and resets metrics.",
        "settings.data.clear": "Reset metrics / Clear data",
        "settings.data.clear_alert.title": "Clear data",
        "settings.data.clear_alert.message": "Do you really want to clear your data?",
        "settings.data.clear_alert.cancel": "Cancel",
        "settings.data.clear_alert.confirm": "Yes, clear",
        "settings.section.backup": "Backup",
        "settings.backup.help": "Backup only saves sessions and metrics so you can restore on another computer.",
        "settings.backup.auto": "Automatic backup",
        "settings.backup.folder": "Folder",
        "settings.backup.folder.none": "Not selected",
        "settings.backup.choose_folder": "Choose folder",
        "settings.backup.now": "Back up now",
        "settings.backup.import": "Import backup",
        "settings.backup.last": "Last backup: %@",
        "settings.section.dev": "Development",
        "settings.dev.seed": "Generate test data (60 days)",
        "settings.app_picker.title": "Choose the app allowed during focus",
        "settings.app_picker.prompt": "Select app",

        // Backup messages
        "backup.status.auto_disabled": "Automatic backup disabled.",
        "backup.status.no_folder": "Automatic backup not enabled: folder not selected.",
        "backup.status.auto_enabled": "Automatic backup enabled.",
        "backup.status.folder_set": "Backup folder configured.",
        "backup.status.saved": "Backup saved to %@.",
        "backup.status.imported": "Backup imported: %d sessions restored.",
        "backup.status.auto_failed": "Automatic backup failed: %@",
        "backup.errors.no_folder": "Select a folder to save the backup.",
        "backup.errors.invalid_file": "Invalid backup file.",
        "backup.errors.cannot_create": "Couldn't prepare the backup folder.",
        "backup.errors.cannot_write": "Couldn't save the backup file.",
        "backup.errors.cannot_read": "Couldn't read the backup file.",

        // Timer
        "timer.phase.focus": "StatFocus",
        "timer.phase.break": "Break",
        "timer.help.lock_close": "Total Focus active: timer can't be hidden",
        "timer.help.lock_pause": "Total Focus active: pause disabled",
        "timer.help.reset": "Reset count",
        "timer.help.skip_break": "Skip break",
        "timer.menu.focus_duration": "Focus duration",
        "timer.menu.break_duration": "Break duration",
        "timer.menu.daily_goal": "Daily goal",
        "timer.menu.weekly_goal": "Weekly goal",
        "timer.menu.sound": "Notification sound",
        "timer.menu.auto_hide": "Hide when focus starts",
        "timer.menu.total_focus": "Total Focus",
        "timer.menu.open_settings": "Open settings",
        "timer.menu.hide_timer": "Hide timer",

        // AppDelegate notification setup alert
        "alert.notif_setup.title": "Configure notification blocking",
        "alert.notif_setup.message": "To block notifications during focus, the app tries to enable Do Not Disturb automatically.\nIf it fails on your macOS, create these shortcuts in the Shortcuts app:\n1) StatFocus - Notificacoes OFF\n2) StatFocus - Notificacoes ON\nIn each one, use the action to set the 'Do Not Disturb' Focus on/off.",
        "alert.notif_setup.open_shortcuts": "Open Shortcuts",
        "alert.notif_setup.later": "Later",

        // Language toggle button accessibility
        "lang.toggle.help": "Toggle language",

        // Soft blocker banner
        "blocker.soft.title": "Focus active",
        "blocker.soft.message": "You opened %@",
    ]
}
