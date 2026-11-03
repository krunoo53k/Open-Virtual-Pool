extends Node

## Headless fixture replay for issue #6's acceptance: the scenarios in
## `fixtures/eight_ball_fixtures.json` are ground truth for the ruling and the
## announce signal order. Every shot goes through the real `EightBallRules`
## scene instance; the runner folds each ruling into a fresh `MatchState` the
## way `game.tscn` will in card #8. The exit code is the number of shots whose
## ruling or signal order said no.

const FIXTURES := "res://fixtures/eight_ball_fixtures.json"
const FIELDS := ["foul_reason", "next_player", "ball_in_hand", "re_rack", "solids_player", "game_over", "winner"]

var _failures := 0
var _shots := 0
var _announced: Array[String] = []
var _rules: Node = null


func _on_foul(reason: String) -> void:
    _announced.append("foul_committed:" + reason)


func _on_groups(player: int) -> void:
    _announced.append("groups_assigned:%d" % player)


func _on_grant(player: int) -> void:
    _announced.append("ball_in_hand_granted:%d" % player)


func _on_turn(player: int) -> void:
    _announced.append("turn_changed:%d" % player)


func _on_over(winner: int) -> void:
    _announced.append("game_over:%d" % winner)


func _ready() -> void:
    _rules = $Rules
    _rules.foul_committed.connect(self._on_foul)
    _rules.groups_assigned.connect(self._on_groups)
    _rules.ball_in_hand_granted.connect(self._on_grant)
    _rules.turn_changed.connect(self._on_turn)
    _rules.game_over.connect(self._on_over)
    var file := FileAccess.open(FIXTURES, FileAccess.READ)
    if file == null:
        prints("fixture-test: cannot open", FIXTURES)
        get_tree().quit(1)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed == null or not (parsed is Dictionary) or not parsed.has("fixtures"):
        prints("fixture-test: fixtures JSON unreadable")
        get_tree().quit(1)
        return
    for fixture in parsed["fixtures"]:
        _run_fixture(fixture)
    prints("fixture-test:", _failures, "of", _shots, "shots said no")
    get_tree().quit(_failures)


func _full_rack() -> Array[int]:
    var r: Array[int] = []
    for i in range(1, 16):
        r.append(i)
    return r


func _mk(shot: Dictionary) -> Dictionary:
    var p := ShotParams.new()
    p.called_pocket = int(shot["params"].get("called_pocket", -1))
    var o := ShotOutcome.new()
    # the fixture's outcome_of is the core's detail word; the phase word maps from it
    var words := {"solved": "settled", "settling": "settling"}
    o.phase = words.get(String(shot["outcome"].get("outcome_of", "")), "faulted")
    o.miscue = bool(shot["outcome"].get("miscue", false))
    o.foul = bool(shot["outcome"].get("foul", false))
    var evs: Array[ShotEvent] = []
    for d in shot["events"]:
        var e := ShotEvent.new()
        e.kind = String(d["kind"])
        e.ball = int(d["ball"])
        e.other = int(d["other"])
        e.time = float(d["time"])
        evs.append(e)
    return {"params": p, "outcome": o, "events": evs}


func _run_fixture(fixture: Dictionary) -> void:
    prints("-- fixture:", fixture["name"])
    var state := MatchState.new()
    state.player = 1
    state.remaining = _full_rack()
    state.break_next = true
    for shot in fixture["shots"]:
        _shots += 1
        _announced.clear()
        var made := _mk(shot)
        var ruling: Variant = _rules.judge_and_announce(made["outcome"], made["params"], made["events"], state)
        _check(shot, ruling)
        if ruling.game_over:
            break
        # the composer's own fold: the ruling onto state plus its remaining-ball bookkeeping
        var potted: Array[int] = []
        for e in made["events"]:
            if e.kind == "pocket-drop" and e.ball != 0:
                potted.append(e.ball)
        state.player = ruling.next_player
        state.ball_in_hand = ruling.ball_in_hand
        if ruling.solids_player != 0:
            state.solids_player = ruling.solids_player
        state.break_next = ruling.re_rack
        if ruling.re_rack:
            state.remaining = _full_rack()
        else:
            var rem: Array[int] = []
            for n in state.remaining:
                if not potted.has(n):
                    rem.append(n)
            state.remaining = rem


func _check(shot: Dictionary, ruling) -> void:
    var bad: Array[String] = []
    for field in FIELDS:
        var want = shot["expect"][field]
        var got = ruling.get(field)
        if got != want:
            bad.append("%s got %s want %s" % [field, got, want])
    var want_signals = shot["expect"]["signals"]
    if _announced != want_signals:
        bad.append("signals got %s want %s" % [", ".join(_announced), ", ".join(want_signals)])
    if bad.size() == 0:
        prints("  PASS:", shot["name"])
    else:
        _failures += 1
        prints("  FAIL:", shot["name"])
        for problem in bad:
            prints("   ", problem)
