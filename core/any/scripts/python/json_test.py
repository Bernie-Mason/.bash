import json

class moas:
  def __init__(self, id, schools):
    self.id = id
    self.schools = schools

moas_instance = moas("EU132234", ["West chesterershire", "Huffingtons schools for huffs", "The bin"])

jsonstr = json.dumps(moas_instance.__dict__)

print("\n\r")
print(jsonstr)

# print(moas_instance.id)
# print(moas_instance.schools)
# print('My class id: {moas_instance.id}')
print(f'My class id: {moas_instance.id}')
print(f"All the schools: {moas_instance.schools}")

