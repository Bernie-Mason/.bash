#!/bin/bash

# Example script demonstrating returning values of different types from functions

# Function to return a scalar value
function return_scalar() {
    echo "Hello, World!"  # Return a scalar value
}

# Function to return an array
function return_array() {
    local -a array=("apple" "banana" "cherry")  # Define an array
    echo "${array[@]}"  # Return the array as a space-separated string
}

# Function to return an associative array
function return_associative_array() {
    declare -A assoc_array=(
        ["name"]="John Doe"
        ["age"]="30"
        ["city"]="New York"
    )
    for key in "${!assoc_array[@]}"; do
        echo "$key=${assoc_array[$key]}"  # Return key=value pairs
    done
}

# Function to return a readonly scalar value
function return_readonly() {
    local readonly_value="This is readonly"
    echo "$readonly_value"  # Return the readonly value
}

# Function to return a nameref (indirectly modify a variable)
function return_nameref() {
    declare -n ref=$1  # Name reference to the passed variable
    ref="Modified by nameref"  # Modify the referenced variable
}

# Function to modify an associative array passed by name
function modify_associative_array() {
    declare -n assoc_array_ref=$1  # Create a name reference to the associative array
    assoc_array_ref["country"]="USA"  # Add a new key-value pair
    assoc_array_ref["city"]="San Francisco"  # Modify an existing key-value pair
    echo "Inside function: Modified associative array:"
    for key in "${!assoc_array_ref[@]}"; do
        echo "  $key: ${assoc_array_ref[$key]}"
    done
}

# Main script

# Scalar value
scalar_value=$(return_scalar)
echo "Scalar value: $scalar_value"

# Array
array_value=($(return_array))  # Capture the returned array
echo "Array elements:"
for element in "${array_value[@]}"; do
    echo "  $element"
done

# Associative array
declare -A assoc_array_value
while IFS='=' read -r key value; do
    assoc_array_value["$key"]="$value"
done < <(return_associative_array)
echo "Associative array elements:"
for key in "${!assoc_array_value[@]}"; do
    echo "  $key: ${assoc_array_value[$key]}"
done

# Pass the associative array by name
declare -A my_assoc_array=(
    ["name"]="John Doe"
    ["age"]="30"
    ["city"]="New York"
)

echo "Before function call:"
for key in "${!my_assoc_array[@]}"; do
    echo "  $key: ${my_assoc_array[$key]}"
done

modify_associative_array my_assoc_array

echo "After function call:"
for key in "${!my_assoc_array[@]}"; do
    echo "  $key: ${my_assoc_array[$key]}"
done

# Readonly scalar value
readonly_value=$(return_readonly)
echo "Readonly value: $readonly_value"

# Nameref
original_var="Original value"
return_nameref original_var
echo "Nameref modified value: $original_var"