#!/bin/bash

# Example script demonstrating variable type detection and returning the type

# Function to detect and return the type of a scalar variable
function detect_scalar_type() {
    local scalar_value=$1
    if [[ "$scalar_value" =~ ^[0-9]+$ ]]; then
        echo "integer"
    elif [[ "$scalar_value" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "float"
    else
        echo "string"
    fi
}

# Function to detect and return the type of an array
function detect_array_type() {
    declare -n array_ref=$1  # Name reference to the array
    if [[ -n "${array_ref[@]}" ]]; then
        echo "array"
    else
        echo "empty array"
    fi
}

# Function to detect and return the type of an associative array
function detect_associative_array_type() {
    declare -n assoc_array_ref=$1  # Name reference to the associative array
    if [[ -n "${!assoc_array_ref[@]}" ]]; then
        echo "associative array"
    else
        echo "empty associative array"
    fi
}

# Function to detect and return the type of a readonly variable
function detect_readonly_type() {
    local readonly_value=$1
    if [[ -z "$readonly_value" ]]; then
        echo "empty readonly"
    else
        echo "readonly"
    fi
}

# Function to detect and return the type of a nameref
function detect_nameref_type() {
    declare -n nameref_var=$1  # Name reference to another variable
    if [[ -n "$nameref_var" ]]; then
        echo "nameref"
    else
        echo "empty nameref"
    fi
}

# Main script

# Scalar variable
scalar_var="Hello, World!"
scalar_type=$(detect_scalar_type "$scalar_var")
echo "Scalar type: $scalar_type"

# Integer scalar variable
integer_var=42
integer_type=$(detect_scalar_type "$integer_var")
echo "Integer type: $integer_type"

# Array
array_var=("apple" "banana" "cherry")
array_type=$(detect_array_type array_var)
echo "Array type: $array_type"

# Associative array
declare -A assoc_array_var=(
    ["name"]="John Doe"
    ["age"]="30"
    ["city"]="New York"
)
assoc_array_type=$(detect_associative_array_type assoc_array_var)
echo "Associative array type: $assoc_array_type"

# Readonly variable
readonly readonly_var="This is readonly"
readonly_type=$(detect_readonly_type "$readonly_var")
echo "Readonly type: $readonly_type"

# Nameref
original_var="I am the original variable"
nameref_type=$(detect_nameref_type original_var)
echo "Nameref type: $nameref_type"