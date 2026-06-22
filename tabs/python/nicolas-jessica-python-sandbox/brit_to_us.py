#!/usr/bin/env python3
"""British-English to American-English exercise from portfolio screenshot."""

british_words = ["flavour", "humour", "labour"]
american_to_british_words = {
    "flavour": "flavor",
    "humour": "humor",
    "labour": "labor",
}

SAMPLE_TEXT = (
    "I love apples for their flavour but growing them is a lot of labour ! "
    "Sadly, having humour does not help."
)

custom_list_british_words = []


def brit_to_us(my_text_input: str) -> None:
    print()
    for word in my_text_input.split(" "):
        if word not in british_words:
            print(word, end=" ")
        else:
            print(word.replace(word, american_to_british_words[word]), end=" ")
            custom_list_british_words.append(word)
    print("\nWords that were changed: " + str(custom_list_british_words))


if __name__ == "__main__":
    my_text_input = str(input("Enter your text in british english here: "))
    brit_to_us(my_text_input)
