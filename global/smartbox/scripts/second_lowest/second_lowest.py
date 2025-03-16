
# Problem: Given an array of integers, return the second lowest value in the array. If the array contains less than two elements, raise a ValueError. If the array contains less than two unique elements, raise a ValueError.
# Returns the second lowest value in the array.
# param numbers: List of integers

class Solution
    def seond_lowest(self, numbers):
        if len(numbers) < 2:
            raise ValueError("Array must contain at least two elements")

        first, second = float('inf'), float('inf')
        for num in numbers:
            if num < first:
                second = first
                first = num
            elif first < num < second:
                second = num

        if second == float('inf'):
            raise ValueError("Array must contain at least two unique elements")

        return second

def second_lowest(numbers):
    """
    Returns the second lowest value in the array.
    
    :param numbers: List of integers
    :return: Second lowest integer
    """
    if len(numbers) < 2:
        raise ValueError("Array must contain at least two elements")

    first, second = float('inf'), float('inf')
    for num in numbers:
        if num < first:
            second = first
            first = num
        elif first < num < second:
            second = num

    if second == float('inf'):
        raise ValueError("Array must contain at least two unique elements")

    return second

# Example usage
if __name__ == "__main__":
    numbers = [4, 1, 7, 3, 2, 5, 1, 3]
    print("Second lowest value:", second_lowest(numbers))