# =============================================================================
#  Sonar Shock — Community Bugfix Patch v1.0
#  Fixes: stuck-under-objects after crouching, long-session framerate collapse
#         ("memory leak"), low-sanity elevator soft-lock, minor script bugs.
#
#  What this script does, in order:
#    1. Finds your "Sonar Shock.pck" and checks its SHA-256 fingerprint.
#       It ONLY proceeds on the exact game build this patch was made for.
#    2. Reads the 12 affected scripts out of your own pck, applies the changes
#       from SonarShock_bugfixes.patch in memory, and verifies every result
#       against known-good fingerprints. Any mismatch -> it stops, changing
#       nothing.
#    3. Backs up your pck to "Sonar Shock.pck.orig", then writes the patched
#       scripts into the pck.
#    4. Re-fingerprints the finished file against the expected result. If it
#       doesn't match exactly, your backup is restored automatically.
#
#  Nothing else is touched: no exe, no DLLs, no save files.
#  Undo any time: run RestoreOriginal.bat (or copy the .orig back yourself).
# =============================================================================
$ErrorActionPreference = 'Stop'

$PatchVersion      = '1.0'
$PatchFileName     = 'SonarShock_bugfixes.patch'
$OriginalPckSha256 = '98332c90d863c6ecf975cc29342608ef2a8732787de9f10fbc459cdd1ead7e01'
$PatchedPckSha256  = '9f03f18b2aae68e873c8b0d77778834b6c6dd7088f315961126270d81fd7c11e'
$OriginalPckSize   = 1724726304
# Files in pck append order; per-file SHA-256 of the original and patched bytes.
$Files = [ordered]@{
    'player.gd' = @{ Orig = 'c91fee5a5a58d6307250e856bc46ccee461a2a5b3fc870d9d005dcb666e46627'; New = '730900597b7c93f68da327140e66be4b28429746d086715644b43a59c7c63d18' }
    'new_manager.gd' = @{ Orig = '6bb32645c7c61dc0876356348c563c228011a088701bb67bfb0cd4f571765c3c'; New = '87cb1ed2f8a610b82f7c73e009367f375e7a0dec99e90386dee6c30f04247b08' }
    'Maps/main_scene.gd' = @{ Orig = '1401ae60e6952db6d7b56fad6b7e2505347d56693f924d243f4e82205794f4ff'; New = 'ae19ebfbecc52fffce9817a7da249ac8105b6b17d8bf850574bfdb4e511e9f30' }
    'bullethole2.gd' = @{ Orig = '93d6506fe0466aa234e4a736feed2819ec8e7d0d1bcb216cde0f84385fdc91da'; New = '923ed154573fab57cad1f5a3ac67fac628b8fe5fa310f8ff983c9c5cdb36408d' }
    'bullethole4.gd' = @{ Orig = '29d119acd14df8aa6ed22e8da453a172b1f53e4c3513310016598d8b051a35fd'; New = '531660cfb4dccce67d785b6d0be645b36dcc4d86ee67415abf73a3a442c6fe85' }
    'bullethole5.gd' = @{ Orig = '5dd79109dd227c96f70a944af04051f34862eb37b763de2ee1e82e77e79134c4'; New = 'dbc78f4595209c188c038251e90a9d4a1f762aefebccf93abb4bd88175bfc506' }
    'bullethole7.gd' = @{ Orig = 'aa788d6855b0ac0ddc9a81a14674056031c7ac1eb1e19d8aec11cb6b4c731cf0'; New = '7590aaf57eadc75440820d2891122a894d3e4610ece95d16000005f2b9801e79' }
    'bullethole_melee.gd' = @{ Orig = '0914f2522eec947275398a777e46fbd22bdb4a5260ad0bcd87632f40b5c2412a'; New = '31f78ed25eeca0e06e10c096822fa23f88350e96556c1702c44aa6b11748bd01' }
    'sword_bullethole.gd' = @{ Orig = 'bfde5450183a079bf9a8061b3c8fed9c4696b7714e27d998e2b73a625dddc437'; New = '92e1e6194b29dfe4b786f1b29415c1558aaa0d748b56f980779dcb246f27bd7f' }
    'blood_splatter.gd' = @{ Orig = '99a51ac69729875850ad2876dde034f38f8de59c848fa486a0ae2e6602c524aa'; New = '2d4724ec4e49b03552573366c0319d53d399bc51e6efc43e26600bcd4ff39c54' }
    'blood_sprite.gd' = @{ Orig = '918678bfd324ae5ae6b8cf1f25238c80ce07440b269ed76e6d9f767e49c23e27'; New = '37755167d2e90f70f6be7ecd36343b0d9e95d8e1fb344852bb0fa66532ef2547' }
    'random/casing1.gd' = @{ Orig = '070cd87a48360fe7238bba34fc533515e67c6fd77df040675a88978fc302b0a9'; New = 'de0d79f094b58bd2f29ca4ec65e78fa06aa24e8822e0bd2323b635ed60a5cdca' }
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$m) { Write-Host ("   " + $m) }
function Write-Ok([string]$m)   { Write-Host (" [OK] " + $m) -ForegroundColor Green }
function Write-Bad([string]$m)  { Write-Host (" [!!] " + $m) -ForegroundColor Red }

function Get-BytesSha256([byte[]]$b) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($b) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}

function Get-BytesMd5([byte[]]$b) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { return $md5.ComputeHash($b) } finally { $md5.Dispose() }
}

function Test-StrEq([string]$a, [string]$b) {
    return [string]::Equals($a, $b, [System.StringComparison]::Ordinal)
}

# ---------------------------------------------------------------------------
# Unified-diff parsing (strict). Nothing before the first "diff --git" line is
# treated as diff syntax, and hunk bodies are consumed by their stated line
# counts, so the human-readable preamble in the .patch can never confuse it.
# ---------------------------------------------------------------------------
function Read-PatchSections([string]$patchPath) {
    $text = $Utf8.GetString([System.IO.File]::ReadAllBytes($patchPath))
    if ($text.IndexOf("`r") -ge 0) { $text = $text.Replace("`r", "") }
    $lines = $text.Split("`n")
    $sections = @{}
    $hunkRe = [regex]'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@'
    $i = 0; $inDiff = $false; $cur = $null
    while ($i -lt $lines.Length) {
        $ln = $lines[$i]
        if ($ln.StartsWith('diff --git ')) { $inDiff = $true; $cur = $null; $i++; continue }
        if ($inDiff -and $ln.StartsWith('+++ b/')) {
            $cur = $ln.Substring(6)
            $sections[$cur] = New-Object System.Collections.Generic.List[object]
            $i++; continue
        }
        if ($inDiff -and $null -ne $cur) {
            $m = $hunkRe.Match($ln)
            if ($m.Success) {
                $oldStart = [int]$m.Groups[1].Value
                $oldN = 1; if ($m.Groups[2].Success) { $oldN = [int]$m.Groups[2].Value }
                $newN = 1; if ($m.Groups[4].Success) { $newN = [int]$m.Groups[4].Value }
                $body = New-Object System.Collections.Generic.List[object]
                $i++
                $o = $oldN; $n = $newN
                while ($o -gt 0 -or $n -gt 0) {
                    if ($i -ge $lines.Length) { throw 'The .patch file is truncated inside a hunk.' }
                    $bl = $lines[$i]; $i++
                    if ($bl.Length -eq 0) { $op = ' '; $txt = '' }
                    else {
                        $first = $bl.Substring(0, 1)
                        if ($first -eq ' ')     { $op = ' '; $txt = $bl.Substring(1) }
                        elseif ($first -eq '-') { $op = '-'; $txt = $bl.Substring(1) }
                        elseif ($first -eq '+') { $op = '+'; $txt = $bl.Substring(1) }
                        elseif ($first -eq '\') { continue }
                        else { throw ('The .patch file has a malformed hunk line: ' + $bl) }
                    }
                    $body.Add(@{ Op = $op; Text = $txt })
                    if ($op -ne '+') { $o-- }
                    if ($op -ne '-') { $n-- }
                }
                $sections[$cur].Add(@{ OldStart = $oldStart; Body = $body })
                continue
            }
        }
        $i++
    }
    return $sections
}

# Strict apply: hunks land exactly at their stated line numbers; every context
# and removed line must match the original byte-for-byte or we abort.
function Invoke-StrictApply([string]$origText, $hunks, [string]$name) {
    $orig = $origText.Split("`n")
    $out = New-Object System.Collections.Generic.List[string]
    $idx = 0
    foreach ($h in $hunks) {
        $target = $h.OldStart - 1
        if ($target -lt $idx) { throw ('Overlapping hunks in ' + $name + '.') }
        while ($idx -lt $target) { $out.Add($orig[$idx]); $idx++ }
        foreach ($e in $h.Body) {
            if ($e.Op -eq ' ') {
                if ($idx -ge $orig.Length -or -not (Test-StrEq $orig[$idx] $e.Text)) {
                    throw ('Context mismatch in ' + $name + ' at original line ' + ($idx + 1) + '.')
                }
                $out.Add($orig[$idx]); $idx++
            }
            elseif ($e.Op -eq '-') {
                if ($idx -ge $orig.Length -or -not (Test-StrEq $orig[$idx] $e.Text)) {
                    throw ('Removed-line mismatch in ' + $name + ' at original line ' + ($idx + 1) + '.')
                }
                $idx++
            }
            else { $out.Add($e.Text) }
        }
    }
    while ($idx -lt $orig.Length) { $out.Add($orig[$idx]); $idx++ }
    return [string]::Join("`n", $out.ToArray())
}

# ---------------------------------------------------------------------------
# Godot PCK v2 directory
# ---------------------------------------------------------------------------
function Read-PckDirectory([string]$pckPath) {
    $fs = [System.IO.File]::Open($pckPath, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $br = New-Object System.IO.BinaryReader($fs)
        if ($Utf8.GetString($br.ReadBytes(4)) -ne 'GDPC') { throw 'Not a Godot .pck file (bad magic).' }
        $fmt = $br.ReadUInt32()
        $vMaj = $br.ReadUInt32(); $vMin = $br.ReadUInt32(); $vPat = $br.ReadUInt32()
        if ($fmt -ne 2) { throw ('Unsupported pck format version ' + $fmt + '.') }
        $flags = $br.ReadUInt32()
        if (($flags -band 1) -ne 0) { throw 'This pck has an encrypted directory and cannot be patched.' }
        $fileBase = $br.ReadUInt64()
        [void]$fs.Seek(64, [System.IO.SeekOrigin]::Current)
        $count = $br.ReadUInt32()
        $entries = @{}
        for ($i = 0; $i -lt $count; $i++) {
            $plen = $br.ReadUInt32()
            $path = $Utf8.GetString($br.ReadBytes([int]$plen)).TrimEnd([char]0)
            $fieldsOff = $fs.Position
            $off = $br.ReadUInt64(); $size = $br.ReadUInt64()
            $md5 = $br.ReadBytes(16)
            [void]$br.ReadUInt32()
            $entries[$path] = @{ Off = $off; Size = $size; Md5 = $md5; FieldsOff = $fieldsOff }
        }
        return @{ FileBase = $fileBase; Entries = $entries; Engine = ('' + $vMaj + '.' + $vMin + '.' + $vPat) }
    }
    finally { $fs.Dispose() }
}

function Read-PckEntry([string]$pckPath, $dir, [string]$resPath) {
    $e = $dir.Entries[$resPath]
    if ($null -eq $e) { throw ('Entry missing from pck: ' + $resPath) }
    $fs = [System.IO.File]::Open($pckPath, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        [void]$fs.Seek([long]($dir.FileBase + $e.Off), [System.IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] ([int]$e.Size)
        $read = $fs.Read($buf, 0, $buf.Length)
        if ($read -ne $buf.Length) { throw ('Short read on ' + $resPath) }
        return $buf
    }
    finally { $fs.Dispose() }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ('  Sonar Shock - Community Bugfix Patch v' + $PatchVersion) -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

$exitCode = 1
try {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

    $patchPath = Join-Path $scriptDir $PatchFileName
    if (-not (Test-Path -LiteralPath $patchPath)) {
        throw ('"' + $PatchFileName + '" must be in the same folder as this script.')
    }

    # --- locate the game ---
    $gameDir = $null
    $parentDir = Split-Path -Parent $scriptDir
    foreach ($c in @($scriptDir, $parentDir)) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'Sonar Shock.pck'))) { $gameDir = $c; break }
    }
    while (-not $gameDir) {
        Write-Host 'Could not find "Sonar Shock.pck" next to this script.'
        $inp = Read-Host 'Type (or paste) the full path of your Sonar Shock folder'
        $inp = $inp.Trim().Trim('"')
        if ($inp -and (Test-Path -LiteralPath (Join-Path $inp 'Sonar Shock.pck'))) { $gameDir = $inp }
        else { Write-Bad 'No "Sonar Shock.pck" there - try again (Ctrl+C to quit).' }
    }
    $pckPath = Join-Path $gameDir 'Sonar Shock.pck'
    $backupPath = Join-Path $gameDir 'Sonar Shock.pck.orig'
    Write-Ok ('Game found: ' + $gameDir)

    # --- step 1: identify the pck ---
    Write-Step 'Checking your game files (hashing 1.7 GB, this takes a few seconds)...'
    $pckHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $pckPath).Hash.ToLowerInvariant()
    if ($pckHash -eq $PatchedPckSha256) {
        Write-Ok 'This game is ALREADY PATCHED. Nothing to do.'
        exit 0
    }
    if ($pckHash -ne $OriginalPckSha256) {
        Write-Bad 'Your "Sonar Shock.pck" is not the game build this patch was made for.'
        Write-Step 'It may be a newer/older game version, or an already-modified file.'
        Write-Step 'To get a clean copy: Steam -> game Properties -> Installed Files ->'
        Write-Step '"Verify integrity of game files", then run this patcher again.'
        Write-Step ('(Expected SHA-256 ' + $OriginalPckSha256.Substring(0, 16) + '..., found ' + $pckHash.Substring(0, 16) + '...)')
        exit 1
    }
    Write-Ok 'Exact original game build confirmed.'

    # --- step 2: parse pck + patch, rebuild the 12 scripts in memory ---
    $dir = Read-PckDirectory $pckPath
    Write-Ok ('PCK opened: Godot ' + $dir.Engine + ', ' + $dir.Entries.Count + ' files.')

    $sections = Read-PatchSections $patchPath
    foreach ($relPath in $Files.Keys) {
        if (-not $sections.ContainsKey($relPath)) { throw ('The .patch file has no section for ' + $relPath + '.') }
    }
    Write-Ok ('Patch file parsed: ' + $sections.Count + ' file sections.')

    $newContent = @{}
    foreach ($relPath in $Files.Keys) {
        $resPath = 'res://' + $relPath
        $origBytes = Read-PckEntry $pckPath $dir $resPath
        if ((Get-BytesSha256 $origBytes) -ne $Files[$relPath].Orig) {
            throw ('Extracted ' + $relPath + ' does not match the expected original.')
        }
        $patchedText = Invoke-StrictApply ($Utf8.GetString($origBytes)) $sections[$relPath] $relPath
        $patchedBytes = $Utf8.GetBytes($patchedText)
        if ((Get-BytesSha256 $patchedBytes) -ne $Files[$relPath].New) {
            throw ('Patched ' + $relPath + ' does not match the expected result - refusing to write.')
        }
        $newContent[$relPath] = $patchedBytes
    }
    Write-Ok ('All ' + $newContent.Count + ' patched scripts rebuilt and verified in memory.')

    # --- step 3: free space + backup ---
    $required = 200MB
    if (-not (Test-Path -LiteralPath $backupPath)) { $required = $OriginalPckSize + 200MB }
    $free = $null
    try {
        $root = [System.IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $pckPath).ProviderPath)
        $di = New-Object System.IO.DriveInfo($root)
        $free = $di.AvailableFreeSpace
    } catch { Write-Step 'Could not determine free disk space - skipping that check.' }
    if ($null -ne $free -and $free -lt $required) {
        throw ('Not enough free disk space: need about ' + [math]::Ceiling($required / 1GB) + ' GB for the safety backup.')
    }

    if (Test-Path -LiteralPath $backupPath) {
        $bh = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupPath).Hash.ToLowerInvariant()
        if ($bh -ne $OriginalPckSha256) {
            throw ('A "Sonar Shock.pck.orig" already exists but is NOT the expected original - not touching it. Move it away and retry.')
        }
        Write-Ok 'Existing backup verified - reusing it.'
    }
    else {
        Write-Step 'Creating safety backup "Sonar Shock.pck.orig" (copying 1.7 GB)...'
        Copy-Item -LiteralPath $pckPath -Destination $backupPath
        Write-Ok 'Backup created.'
    }

    # --- step 4: write into the pck (append data, rewrite 12 directory entries) ---
    Write-Step 'Writing patched scripts into the pck...'
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($pckPath, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $bw = New-Object System.IO.BinaryWriter($fs)
        [void]$fs.Seek(0, [System.IO.SeekOrigin]::End)
        $pad = (16 - ($fs.Length % 16)) % 16
        if ($pad -gt 0) { $bw.Write((New-Object byte[] ([int]$pad))) }
        $updates = New-Object System.Collections.Generic.List[object]
        foreach ($relPath in $Files.Keys) {
            $bytes = $newContent[$relPath]
            $dataPos = $fs.Position
            $bw.Write($bytes)
            $p2 = (16 - ($bytes.Length % 16)) % 16
            if ($p2 -gt 0) { $bw.Write((New-Object byte[] ([int]$p2))) }
            $entry = $dir.Entries[('res://' + $relPath)]
            $updates.Add(@{
                FieldsOff = $entry.FieldsOff
                NewOff    = [uint64]$dataPos - $dir.FileBase
                NewSize   = [uint64]$bytes.Length
                NewMd5    = (Get-BytesMd5 $bytes)
            })
        }
        foreach ($u in $updates) {
            [void]$fs.Seek([long]$u.FieldsOff, [System.IO.SeekOrigin]::Begin)
            $bw.Write([uint64]$u.NewOff)
            $bw.Write([uint64]$u.NewSize)
            $bw.Write([byte[]]$u.NewMd5)
        }
        $bw.Flush()
    }
    catch [System.IO.IOException] {
        throw ('Could not write to the pck - close the game (and Steam downloads) and retry. Details: ' + $_.Exception.Message)
    }
    finally { if ($null -ne $fs) { $fs.Dispose() } }

    # --- step 5: final end-to-end verification ---
    Write-Step 'Verifying the finished file (hashing again)...'
    $finalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $pckPath).Hash.ToLowerInvariant()
    if ($finalHash -ne $PatchedPckSha256) {
        Write-Bad 'Final verification FAILED - restoring your backup...'
        Copy-Item -LiteralPath $backupPath -Destination $pckPath -Force
        throw 'The patched file did not verify; your original was restored. Nothing is changed.'
    }

    Write-Host ''
    Write-Ok 'SUCCESS - Sonar Shock is patched. Enjoy!'
    Write-Step 'Fixed: crouch stuck-in-geometry, long-session FPS decay, elevator soft-lock, misc.'
    Write-Step 'Your original data is kept as "Sonar Shock.pck.orig".'
    Write-Step 'To undo: run RestoreOriginal.bat.'
    $exitCode = 0
}
catch {
    Write-Host ''
    Write-Bad ('FAILED: ' + $_.Exception.Message)
    Write-Step 'No changes were kept. Your game is safe.'
    $exitCode = 1
}
exit $exitCode
