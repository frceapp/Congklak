extends RefCounted
## Lawan komputer: minimax dengan pemangkasan alpha-beta di atas CongklakLogic.

## Kedalaman pencarian per tingkat kesulitan (Mudah, Sedang, Sulit).
const DEPTHS: Array[int] = [1, 3, 6]
const WIN_BONUS := 1000.0


static func choose_move(state: RefCounted, level: int) -> int:
	var moves: Array[int] = state.legal_moves()
	if moves.is_empty():
		return -1
	if moves.size() == 1:
		return moves[0]
	level = clampi(level, 0, DEPTHS.size() - 1)
	# Tingkat Mudah: lebih sering asal pilih.
	if level == 0 and randf() < 0.6:
		return moves.pick_random()

	# Papan lebar punya lebih banyak cabang; pencarian didangkalkan supaya
	# komputer tidak berpikir terlalu lama di ponsel.
	var depth := DEPTHS[level]
	if state.holes > 8:
		depth = mini(depth, 5)

	var me: int = state.current
	var best_value := -INF
	var best_moves: Array[int] = []
	for move in moves:
		var child: RefCounted = state.clone()
		child.play(move)
		var value := _search(child, depth - 1, -INF, INF, me)
		if value > best_value + 0.001:
			best_value = value
			best_moves = [move]
		elif absf(value - best_value) <= 0.001:
			best_moves.append(move)
	return best_moves.pick_random()


static func _search(state: RefCounted, depth: int, alpha: float, beta: float, me: int) -> float:
	if depth <= 0 or state.game_over:
		return _evaluate(state, me)
	var moves: Array[int] = state.legal_moves()
	if state.current == me:
		var best := -INF
		for move in moves:
			var child: RefCounted = state.clone()
			child.play(move)
			best = maxf(best, _search(child, depth - 1, alpha, beta, me))
			alpha = maxf(alpha, best)
			if alpha >= beta:
				break
		return best
	var worst := INF
	for move in moves:
		var child: RefCounted = state.clone()
		child.play(move)
		worst = minf(worst, _search(child, depth - 1, alpha, beta, me))
		beta = minf(beta, worst)
		if alpha >= beta:
			break
	return worst


static func _evaluate(state: RefCounted, me: int) -> float:
	var mine: int = state.score(me)
	var theirs: int = state.score(1 - me)
	var value := float(mine - theirs)
	# Lebih dari separuh biji di lumbung berarti sudah pasti menang.
	var total: int = state.total_seeds()
	if mine * 2 > total:
		value += WIN_BONUS
	elif theirs * 2 > total:
		value -= WIN_BONUS
	return value
