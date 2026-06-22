#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#V2 is cleaner Python: it builds strings with list comprehensions and returns them, then prints them.

keyword1 = [
    "opérateur",
    "opérateurs",
    "opératrice",
    "opératrices",
    "operateur",
    "operateurs",
    "operatrice",
    "operatrices",
]

keyword2 = ["contrôle", "contrôles", "controle", "controles"]


def rule_generator_quotes() -> str:
    phrases = [f'"{x} {y}"' for x in keyword1 for y in keyword2]
    return "title:(" + " OR ".join(phrases) + ")"


def rule_generator_parentheses() -> str:
    left = " OR ".join(keyword1)
    right = " OR ".join(keyword2)
    return f"title:(({left}) ({right}))"


if __name__ == "__main__":
    print("Rule with quotes:")
    print()
    print(rule_generator_quotes())
    print()
    print("--------------------")
    print()
    print("Rule with parentheses:")
    print()
    print(rule_generator_parentheses())
