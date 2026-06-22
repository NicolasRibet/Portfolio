#!/usr/bin/python
# -*- coding: utf-8 -*-

#keyword1 = ["assistant", "assistante", "assistants", "assistantes", "d’assistant", "d’assistante", "d’assistants", "d’assistantes", "d'assistant", "d'assistante", "d'assistants"]
#keyword2 = ["médical", "médicale", "médicales", "medical", "medicale", "medicales"]

keyword1 = ["opérateur", "opérateurs", "opératrice", "opératrices", "operateur", "operateurs", "operatrice", "operatrices" ]

keyword2 = ["contrôle", "contrôles", "controle", "controles"]

def rule_generator_quotes():
    #generate all combinations from the 2 lists and make it a CG rule with quotes.
    print("Rule with quotes: ")
    print("\n")
    print("title:(" , end="")
    n = 0
    for x in keyword1:
        for y in keyword2:
            print("\"" + x + " " + y + "\"" , end="")
            if n < (len(keyword1) -1):
                print(" OR " , end="")
            else:
                break
        n += 1
    print(" OR " , end="")
    for z in keyword2[1:-1]:
        print("\"" + keyword1[-1] + " " + z + "\"" + " OR " , end="")
    print("\"" + keyword1[-1] + " " + keyword2[-1] + "\"" , end="")
    print(")")


def rule_generator_parentheses():
    #generate all combinations from the 2 lists and make it a CG rule with parentheses.
    print("Rule with parentheses: ")
    print("\n")
    print("title:((" , end="")
    n = 0
    for x in keyword1:
        if n < (len(keyword1) -1):
            print(x + " OR " , end="")
        else:
            print(x, end="")
        n += 1
    print(") (" , end="")
    for y in keyword2[:-1]:
        print(y + " OR " , end="")
    print(keyword2[-1] + ")" , end="")
    print(")")


rule_generator_quotes()

print("\n" + "--------------------" + "\n")

rule_generator_parentheses()
