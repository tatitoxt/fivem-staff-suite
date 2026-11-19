function StaffSuiteTranslate(key, vars)
  local locale = Locale[Config.Locale] or Locale.en
  local text = locale[key] or Locale.en[key] or key
  if not vars then return text end
  return (text:gsub('%%{([%w_]+)}', function(name)
    local value = vars[name]
    if value ~= nil then return tostring(value) end
  end))
end
