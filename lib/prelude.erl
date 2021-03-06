not(false) -> true;
not(true) -> false.

null([]) -> true;
null(Other) -> false.

append([X|Xs], Ys) -> [X|append(Xs,Ys)];
append([], Ys) -> Ys.

concatMap(F, [X|Xs]) -> F(X) ++ concatMap(F, Xs);
concatMap(F, []) -> [].

map(F, []) -> [];
map(F, [X|Xs]) -> [F(X)|map(F,Xs)].

lengthPlus([X|Xs], Acc) -> lengthPlus(Xs, 1+Acc);
lengthPlus([], Acc) -> Acc.

length(Xs) -> lengthPlus(Xs, 0).

sumPlus([X|Xs], Acc) -> sumPlus(Xs, X+Acc);
sumPlus([], Acc) -> Acc.

sum(Xs) -> sumPlus(Xs, 0).

enumFromTo(From, To) when From > To -> [];
enumFromTo(From, To) -> [From|enumFromTo(From+1, To)].

replicate(N, X) ->
  if N == 0 -> [];
     true -> [X|replicate(N-1, X)]
  end.

foldr(F, Z, []) -> Z;
foldr(F, Z, [X|Xs]) -> F(X, foldr(F, Z, Xs)).

foldr1(F, [X|Xs]) ->
  case Xs of
    [] -> X;
    Other -> F(X, foldr1(F, Xs))
  end.

filter(P, []) -> [];
filter(P, [X|Xs]) ->
  if P(X) -> filter(P, Xs);
     true -> [X|filter(P, Xs)]
  end.

any(P, []) -> false;
any(P, [X|Xs]) -> P(X) or any(P, Xs).

all(P, []) -> true;
all(P, [X|Xs]) -> P(X) and all(P, Xs).
