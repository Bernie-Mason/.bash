import sys
import argparse

parser = argparse.ArgumentParser(description='Make a cake!')
parser.add_argument('eggies', metavar='N', type=int, nargs='?', help='An integer number of eggies')
parser.add_argument('flour', metavar='M', type=int,
                    nargs='?', help='An integer number of flour')

# parser.add_argument('--sum', dest='accumulate', action='store_const', const=sum, default=max, help='sum the integers (default: find the max)')

args = parser.parse_args()
print(args.eggies)
print(args.flour)
