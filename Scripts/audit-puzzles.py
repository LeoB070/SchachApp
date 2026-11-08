#!/usr/bin/env python3
"""Validation only: uv run --no-project --with python-chess python Scripts/audit-puzzles.py [--engine]
Engine mode repeats the depth-16/MultiPV-2 checks used to select combinations.
"""
import argparse
import json
import pathlib
import shutil
import chess
import chess.engine

args = argparse.ArgumentParser()
args.add_argument('--engine', action='store_true')
options = args.parse_args()
items = json.loads((pathlib.Path(__file__).resolve().parents[1] / 'Sources/ChessAppKit/Resources/puzzles.json').read_text())
assert len(items) >= 50
assert len({p['id'] for p in items}) == len({p['fen'] for p in items}) == len(items)
combinations = [p for p in items if p['id'].startswith('combo-')]
assert len(combinations) >= 6
engine = chess.engine.SimpleEngine.popen_uci(shutil.which('stockfish')) if options.engine else None
try:
    if engine:
        engine.configure({'Threads': 1, 'Hash': 64})
    decisions = 0
    for puzzle in items:
        board = chess.Board(puzzle['fen'])
        assert board.is_valid(), puzzle['id']
        assert len(puzzle['moves']) >= 2 and len(puzzle['moves']) % 2 == 0
        for index, uci in enumerate(puzzle['moves']):
            move = chess.Move.from_uci(uci)
            assert move in board.legal_moves, (puzzle['id'], uci)
            assert move.promotion in (None, chess.QUEEN), (puzzle['id'], 'unsupported promotion')
            if engine and puzzle in combinations and index % 2 == 1:
                choices = engine.analyse(board, chess.engine.Limit(depth=16), multipv=2)
                assert len(choices) == 2
                assert choices[0]['pv'][0] == move, (puzzle['id'], uci, 'best move changed')
                first, second = [c['score'].pov(board.turn).score(mate_score=100000) for c in choices]
                assert first >= 100 and first - second >= 100 and second < 90000, (puzzle['id'], first, second)
                decisions += 1
            board.push(move)
        if any('mate' in theme.lower() for theme in puzzle['themes']):
            assert board.is_checkmate(), puzzle['id']
    print(f'{len(items)} valid, unique, legal puzzle lines; true mate labels; supported promotions; {len(combinations)} combinations')
    if engine:
        print(f'{decisions} solver decisions rechecked with Stockfish depth 16 and two variations')
finally:
    if engine:
        engine.quit()
