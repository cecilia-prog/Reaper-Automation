-- Batch replace SPEECH item source in-place (keep same timeline position) and render
-- Mac + Dropbox-safe paths
-- Requires a track named exactly: SPEECH
-- Requires exactly ONE placeholder item on the SPEECH track (the one to be swapped)
local r = reaper
-- >>> YOUR PATHS <<<
local ROOT     = “/Users/beaf/Antfood Dropbox/ANTFOOD WORLDWIDE/NY — Active/LIGHTSHED - The Great Dictator - 2026/Compositions/SpeechRender”
local TEMPLATE = ROOT .. “/Lightshed_GreatDictator_Template_260115.rpp”
local IN_DIR   = ROOT .. “/input_speech”
local OUT_DIR  = ROOT .. “/output”
local TAIL_SEC = 2.5  -- extra tail for reverb, applause, etc.
-- -------- utilities --------
local function msg(s) r.ShowConsoleMsg(tostring(s) .. “\n”) end
local function list_audio_files(dir)
  local t, i = {}, 0
  while true do
    local f = r.EnumerateFiles(dir, i)
    if not f then break end
    local fl = f:lower()
    if fl:match(“%.wav$“) or fl:match(“%.aif$“) or fl:match(“%.aiff$“) or fl:match(“%.mp3$“) then
      table.insert(t, dir .. “/” .. f)
    end
    i = i + 1
  end
  table.sort(t)
  return t
end
local function basename_noext(path)
  local name = path:match(“([^/]+)$“) or path
  return (name:gsub(“%.%w+$“,”“))
end
local function find_track_by_name(name)
  for i=0, r.CountTracks(0)-1 do
    local tr = r.GetTrack(0, i)
    local _, tn = r.GetTrackName(tr)
    if tn == name then return tr end
  end
  return nil
end
local function get_first_item(track)
  if not track then return nil end
  if r.CountTrackMediaItems(track) == 0 then return nil end
  return r.GetTrackMediaItem(track, 0)
end
local function ensure_dir_exists(path)
  -- minimal check: if path is invalid render will fail; we just warn
  local ok = r.file_exists(path)
  if not ok then
    msg(“WARNING: Output directory may not exist or is not accessible: ” .. path)
  end
end
-- -------- main --------
r.ClearConsole()
msg(“ROOT: ” .. ROOT)
msg(“TEMPLATE: ” .. TEMPLATE)
msg(“IN_DIR: ” .. IN_DIR)
msg(“OUT_DIR: ” .. OUT_DIR)
ensure_dir_exists(OUT_DIR)
-- Open template project
r.Main_openProject(TEMPLATE)
local tr_speech = find_track_by_name(“SPEECH”)
if not tr_speech then
  msg(“ERROR: Track named ‘SPEECH’ not found. Rename your speech track to exactly: SPEECH”)
  return
end
local speech_item = get_first_item(tr_speech)
if not speech_item then
  msg(“ERROR: No item found on SPEECH track. Put one placeholder speech item there in the template.“)
  return
end
-- If there are multiple items on SPEECH, warn (we only use the first)
local item_count = r.CountTrackMediaItems(tr_speech)
if item_count ~= 1 then
  msg(“WARNING: SPEECH track has ” .. tostring(item_count) .. ” items. This script will replace ONLY the FIRST item.“)
end
local files = list_audio_files(IN_DIR)
if #files == 0 then
  msg(“ERROR: No audio files found in input_speech/. Put speech WAV/AIFF/MP3 files in: ” .. IN_DIR)
  return
end
msg(“Found ” .. tostring(#files) .. ” speech files. Starting batch render...“)
-- IMPORTANT:
-- The render command used below relies on ‘most recent render settings’.
-- You MUST do ONE manual render first:
-- File -> Render... Bounds: Time selection, set WAV format, choose any directory, Render once.
for _, speech_path in ipairs(files) do
  local base = basename_noext(speech_path)
  msg(“Processing: ” .. base)
  local take = r.GetActiveTake(speech_item)
  if not take then
    msg(”  ERROR: Speech item has no active take.“)
    goto continue
  end
  -- Replace source media (in-place)
  local new_src = r.PCM_Source_CreateFromFile(speech_path)
  if not new_src then
    msg(”  ERROR: Could not load: ” .. speech_path)
    goto continue
  end
  r.SetMediaItemTake_Source(take, new_src)
  -- Force item length to match the new source length (keeps position/fades; length updates)
  local src_len, _ = r.GetMediaSourceLength(new_src)
  if src_len and src_len > 0 then
    r.SetMediaItemInfo_Value(speech_item, “D_LENGTH”, src_len)
  end
  r.UpdateItemInProject(speech_item)
  -- Render bounds: from item start to item end + tail
  local start_pos = r.GetMediaItemInfo_Value(speech_item, “D_POSITION”)
  local item_len  = r.GetMediaItemInfo_Value(speech_item, “D_LENGTH”)
  local end_pos   = start_pos + item_len + TAIL_SEC
  r.GetSet_LoopTimeRange(true, false, start_pos, end_pos, false)
  -- Output location + name
  r.GetSetProjectInfo_String(0, “RENDER_FILE”, OUT_DIR, true)
  r.GetSetProjectInfo_String(0, “RENDER_PATTERN”, base .. “_PA”, true)
  -- Render using most recent render settings
  r.Main_OnCommand(41824, 0)
  ::continue::
end
msg(“DONE. Check output folder: ” .. OUT_DIR)
