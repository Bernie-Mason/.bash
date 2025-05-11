#!/bin/bash

# Example script demonstrating the use of `declare` with different variable types
# A MAJOR downside of using this technique is that variable names are global
# and can lead to conflicts if not managed properly. For example, if we name the assoc_array_ref
# to assoc_array_var we will create a circular name reference and the script will fail.

# Function to demonstrate passing a scalar variable
function scalar_example() {
    local scalar_value=$1  # Scalar variable passed as an argument
    echo "Scalar value: $scalar_value"
}

# Function to demonstrate passing an array
function array_example() {
    declare -n array_ref=$1  # Name reference to the array
    echo "Array elements:"
    for element in "${array_ref[@]}"; do
        echo "  $element"
    done
}

# Function to demonstrate passing an associative array
function associative_array_example() {
    declare -n assoc_array_ref=$1  # Name reference to the associative array
    echo "Associative array elements:"
    for key in "${!assoc_array_ref[@]}"; do
        echo "  $key: ${assoc_array_ref[$key]}"
    done
}

# Function to demonstrate passing a readonly variable
function readonly_example() {
    declare -r readonly_value=$1  # Readonly variable
    echo "Readonly value: $readonly_value"
}

# Function to demonstrate passing a nameref
function nameref_example() {
    declare -n nameref_var=$1  # Name reference to another variable
    echo "Nameref value: $nameref_var"
}

# Main script

# Scalar variable
scalar_var="Hello, World!"
scalar_example "$scalar_var"

# Array
array_var=("apple" "banana" "cherry")
array_example array_var

# Associative array
declare -A assoc_array_var=(
    ["name"]="John Doe"
    ["age"]="30"
    ["city"]="New York"
)
associative_array_example assoc_array_var

# Readonly variable
readonly_var="This is readonly"
readonly_example "$readonly_var"

# Nameref
original_var="I am the original variable"
nameref_example original_var