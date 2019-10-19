# pl0c
## env
```
$ lex -V
flex 2.5.35 Apple(flex-31)

$ yacc -V
bison (GNU Bison) 2.3
Written by Robert Corbett and Richard Stallman.

$ gcc -v
Apple LLVM version 10.0.1 (clang-1001.0.46.4)
```

## 演算子
`(OPR, 0, a)`
- 0: 手続きから戻る
- 1: 単項-
- 2: +
- 3: -
- 4: *
- 5: /
- 6: val % 2 == 1 ? 1 : 0
- 7: なし
- 8: =
- 9: !=
- 10: <
- 11: >=
- 12: >
- 13: <=
// ここから拡張
- 14: &&
- 15: ||
- 16: !

## if while
for 文はないので `while` に変換
```
if <cond> then begin
  <stmts>
end
```

```
while <cond> do begin
  <stmts>
end
```

## 剰余
剰余演算子 `%` は ないので `x % y` は `x - y * (x / y)` に変換.

## スタック
スコープ毎に予約スタックが3つあるので `STO ( 0, 3 )` から始める.
スタック確保も `INT ( 0, 3 + n )`.

## 引数
最後の引数が `baseptr - 1` 次が `baseptr - 2` ... というように入っている.