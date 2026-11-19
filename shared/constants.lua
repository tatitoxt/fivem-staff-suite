-- shared/constants.lua — nombres de eventos y tipos compartidos.
SS = SS or {}
SS.EVENTS = {
  OPEN_UI = 'staff_suite:client:openUI',
  NUI_ACTION = 'staff_suite:server:nuiAction',
  SYNC = 'staff_suite:client:sync',
  AUDIT_ENTRY = 'staff_suite:server:auditEntry',
}
SS.ACTIONS = {
  'close_ui','set_locale','audit_verify','audit_filter',
  'ticket_claim','ticket_transfer','ticket_resolve','ticket_close','ticket_reopen',
  'ticket_message','ticket_create','mod_action','duty_toggle','refresh',
}
SS.MOD_ACTIONS = { kick=true, ban=true, warn=true, freeze=true, heal=true, teleport=true, spectate=true }
