#!/bin/bash

# Demonstration of Bash variable types and scoping
# typing in Bash is dynamic. 
# This means that variables in Bash are not explicitly declared with a type (e.g., int, string, etc.), 
# and their type is determined by the context in which they are used. 
# Bash treats all variables as strings by default but allows them to be interpreted as other types (e.g., integers or arrays) based on how they are use                                           000000000000000d or declared.

# Default type: String
var="123"
echo "String: $var"

# Implicit conversion to integer
echo "Arithmetic: $((var + 1))"

# Change type dynamically
var=("apple" "banana")  # Now an array
echo "Array element: ${var[0]}"

# Explicit type enforcement
declare -i num=42  # Integer
echo "Integer: $((num + 1))"

declare -A assoc_array=(["key"]="value")  # Associative array
echo "Associative array value: ${assoc_array["key"]}"

# ============================
# 1. Scalar Variables
# ============================
# Scalar variables hold a single value (string or number).
scalar_var="Hello, World!"  # Global scalar variable
echo "Scalar variable: $scalar_var"

# ============================
# 2. Indexed Arrays
# ============================
# Indexed arrays hold a list of values, accessed by numeric indices.
declare -a indexed_array=("apple" "banana" "cherry")
echo "Indexed array elements:"
for element in "${indexed_array[@]}"; do
    echo "  $element"
done

# ============================
# 3. Associative Arrays
# ============================
# Associative arrays hold key-value pairs, accessed by string keys.
declare -A assoc_array=(
    ["name"]="John Doe"
    ["age"]="30"
    ["city"]="New York"
)
echo "Associative array elements:"
for key in "${!assoc_array[@]}"; do
    echo "  $key: ${assoc_array[$key]}"
done

# ============================
# 4. Readonly Variables
# ============================
# Readonly variables cannot be modified after assignment.
readonly readonly_var="This value cannot be changed"
echo "Readonly variable: $readonly_var"
# Uncommenting the next line will cause an error:
# readonly_var="New value"

# ============================
# 5. Nameref Variables
# ============================
# Nameref variables act as references to other variables.
original_var="Original value"
declare -n nameref_var=original_var
echo "Nameref variable before modification: $nameref_var"
nameref_var="Modified via nameref"
echo "Nameref variable after modification: $nameref_var"
echo "Original variable after modification: $original_var"

# ============================
# 6. Global vs Local Variables
# ============================
# Global variables are accessible everywhere, while local variables are scoped to functions.

global_var="I am global"

function demo_local_variable() {
    local local_var="I am local"
    echo "Inside function: global_var = $global_var"
    echo "Inside function: local_var = $local_var"
}

demo_local_variable
echo "Outside function: global_var = $global_var"
# Uncommenting the next line will cause an error because local_var is not accessible outside the function:
# echo "Outside function: local_var = $local_var"

# ============================
# 7. Function Returning Values
# ============================
# Functions can return scalar values using `echo`.
function return_scalar() {
    echo "This is a scalar value"
}
scalar_returned=$(return_scalar)
echo "Returned scalar: $scalar_returned"

# Functions can return arrays by echoing space-separated values.
function return_array() {
    echo "apple banana cherry"
}
array_returned=($(return_array))
echo "Returned array elements:"
for element in "${array_returned[@]}"; do
    echo "  $element"
done

# Functions can return associative arrays as key-value pairs.
function return_assoc_array() {
    echo "name=John Doe"
    echo "age=30"
    echo "city=New York"
}
declare -A assoc_array_returned
while IFS='=' read -r key value; do
    assoc_array_returned["$key"]="$value"
done < <(return_assoc_array)
echo "Returned associative array elements:"
for key in "${!assoc_array_returned[@]}"; do
    echo "  $key: ${assoc_array_returned[$key]}"
done

# ============================
# 8. Modifying Variables by Reference
# ============================
# Functions can modify variables by reference using `declare -n`.
function modify_by_reference() {
    declare -n ref=$1
    ref="Modified by reference"
}
ref_var="Original value"
echo "Before modification: $ref_var"
modify_by_reference ref_var
echo "After modification: $ref_var"

# ============================
# 9. Combining Local and Declare
# ============================
# You can use `local` with `declare` to create function-scoped variables with specific attributes.
function demo_local_and_declare() {
    local -A local_assoc_array=(
        ["key1"]="value1"
        ["key2"]="value2"
    )
    echo "Inside function: Local associative array elements:"
    for key in "${!local_assoc_array[@]}"; do
        echo "  $key: ${local_assoc_array[$key]}"
    done
}
demo_local_and_declare
# Uncommenting the next line will cause an error because local_assoc_array is not accessible outside the function:
# echo "Outside function: ${local_assoc_array[@]}"

# ============================
# End of Script
# ============================
echo "Script demonstration complete!"