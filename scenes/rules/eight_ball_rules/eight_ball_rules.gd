extends Node
class_name EightBallRules

## BCA eight-ball ruling: `ShotOutcome`, `ShotParams`, `ShotEvent` array,
## and the `MatchState` as it was BEFORE the shot in, one `Judgement` out.
## Events are ground truth: the core's `outcome.foul` stays advisory and
## only `outcome.miscue` and the phase word are read (the rules never
## ask physics anything). The ruling never mutates anything: whoever owns
## the `MatchState` - the fixture runner today, `game.tscn` in card #8 -
## applies it along with its own remaining-ball bookkeeping. `judge_and_announce`
## fires the five announcement signals in the order fixtures assert them:
## foul, group assignment, ball-in-hand grant, turn or game over.
## The Rust port (card #11) reimplements this table over the same event
## words, hence the stable reason words below (§7.2's BCA foul table).

signal foul_committed(reason: String)
signal groups_assigned(solids_player: int)
signal ball_in_hand_granted(player: int)
signal turn_changed(player: int)
signal game_over(winner: int)

@export var min_break_rails := 4  # BCA: object balls driven to a rail on the break


func group_of(n: int) -> int:
    if n == 8:
        return 0
    return 1 if n >= 1 and n <= 7 else 2


func _facts(events: Array[ShotEvent]) -> Dictionary:
    var first := -1
    var contact_t := 0.0
    var rail_after := false
    var driven := {}
    var pots: Array[int] = []
    var scratch := false
    var eight_pocket := -1
    var off: Array[int] = []
    for e in events:
        match e.kind:
            "ball-ball":
                # the cue's first touch; object-object before it is noise (§7.3)
                if first < 0 and (e.ball == 0 or e.other == 0):
                    first = e.other if e.ball == 0 else e.ball
                    contact_t = e.time
            "cushion":
                if e.ball != 0:
                    driven[e.ball] = true
                if first >= 0 and e.time > contact_t:
                    rail_after = true
            "pocket-drop":
                # pocket-drop is the only pot: a rattle never counts (§8.2)
                if e.ball == 0:
                    scratch = true
                else:
                    pots.append(e.ball)
                    if e.ball == 8:
                        eight_pocket = e.other
            "off-table":
                if e.ball != 0:
                    off.append(e.ball)
    return {
        "first": first,
        "contact_t": contact_t,
        "rail_after": rail_after,
        "driven": driven,
        "pots": pots,
        "scratch": scratch,
        "eight_pocket": eight_pocket,
        "off": off,
    }


func _foul(facts: Dictionary, outcome: ShotOutcome, state: MatchState, group: int, on_eight: bool) -> String:
    # priority chain, top wins; the reason words are the fixture contract (§7.2)
    if facts.scratch:
        return "scratch"
    if facts.off.size() > 0:
        return "ball_off_table"
    if facts.first >= 0 and not state.break_next:
        if state.solids_player == 0 and facts.first == 8:
            return "wrong_group_first_contact"
        if state.solids_player != 0 and group_of(facts.first) != group and not (facts.first == 8 and on_eight):
            return "wrong_group_first_contact"
    if facts.first < 0 and not state.break_next:
        return "no_contact"
    if facts.first >= 0 and not facts.rail_after and facts.pots.size() == 0 and not state.break_next:
        return "no_rail_after_contact"
    if state.break_next and facts.driven.size() < min_break_rails:
        return "illegal_break"
    if outcome.miscue:
        return "miscue"
    if outcome.phase != "settled":
        return "incomplete_shot"
    return ""


func _rule(outcome: ShotOutcome, params: ShotParams, events: Array[ShotEvent], state: MatchState) -> Judgement:
    var facts := _facts(events)
    var shooter := state.player
    var other := 3 - shooter
    # the shooter's legal group BEFORE the shot: 1 solids, 2 stripes, 0 open
    var group := 0
    if state.solids_player == shooter:
        group = 1
    elif state.solids_player != 0:
        group = 2
    # "on the 8" reads the ball list exactly as BCA has it (§7.6)
    var on_eight := group != 0 and state.remaining.has(8)
    if on_eight:
        for n in state.remaining:
            if n != 8 and group_of(n) == group:
                on_eight = false
    var reason := _foul(facts, outcome, state, group, on_eight)
    var ruling := Judgement.new()
    ruling.foul_reason = reason
    if facts.pots.has(8):
        if state.break_next:
            # the 8 off the break re-racks; the shooter re-breaks, no win or loss (§7.1)
            ruling.re_rack = true
            ruling.next_player = shooter
            return ruling
        ruling.game_over = true
        var called_wins := bool(on_eight and not facts.scratch and params.called_pocket >= 0 and facts.eight_pocket == params.called_pocket and reason == "")
        ruling.winner = shooter if called_wins else other
        ruling.next_player = 0
        return ruling
    if state.break_next and reason != "":
        # a foul break re-racks; the incoming player breaks with ball-in-hand
        ruling.re_rack = true
    ruling.ball_in_hand = reason != ""
    if state.solids_player == 0 and not state.break_next and reason == "" and facts.pots.size() > 0:
        # open table: the first ball potted names the shooter's group (§7.4)
        ruling.solids_player = shooter if group_of(facts.pots[0]) == 1 else other
    var keep := bool(reason == "" and facts.pots.size() > 0)
    if keep and not state.break_next and state.solids_player != 0:
        keep = false
        for n in facts.pots:
            if group_of(n) == group:
                keep = true
    # an own-group pot keeps the shooter; anything else passes the turn (§7.4)
    ruling.next_player = shooter if keep else other
    return ruling


func judge(outcome: ShotOutcome, params: ShotParams, events: Array[ShotEvent], state: MatchState) -> Judgement:
    return _rule(outcome, params, events, state)


func judge_and_announce(outcome: ShotOutcome, params: ShotParams, events: Array[ShotEvent], state: MatchState) -> Judgement:
    # the ruling itself stays silent; announce is the match-facing half
    var ruling := _rule(outcome, params, events, state)
    _announce(ruling)
    return ruling


func _announce(ruling: Judgement) -> void:
    # the order fixtures assert: foul, group, grant, then turn OR game over
    if ruling.foul_reason != "":
        foul_committed.emit(ruling.foul_reason)
    if ruling.solids_player != 0:
        groups_assigned.emit(ruling.solids_player)
    if ruling.ball_in_hand:
        # the grant goes to whoever shoots next: the incoming player (§7.5)
        ball_in_hand_granted.emit(ruling.next_player)
    if ruling.game_over:
        # the result announces the end and never the turn as well (§7.7/§7.9)
        game_over.emit(ruling.winner)
    else:
        turn_changed.emit(ruling.next_player)
