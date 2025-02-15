import json
from typing import List

class GlossDef:
    def __init__(self, para: str, gloss_see_also: List[str]):
        self.para = para
        self.gloss_see_also = gloss_see_also

class GlossEntry:
    def __init__(self, id: str, sort_as: str, gloss_term: str, acronym: str, abbrev: str, gloss_def: GlossDef, gloss_see: str):
        self.id = id
        self.sort_as = sort_as
        self.gloss_term = gloss_term
        self.acronym = acronym
        self.abbrev = abbrev
        self.gloss_def = gloss_def
        self.gloss_see = gloss_see

class GlossList:
    def __init__(self, gloss_entry: GlossEntry):
        self.gloss_entry = gloss_entry

class GlossDiv:
    def __init__(self, title: str, gloss_list: GlossList):
        self.title = title
        self.gloss_list = gloss_list

class Glossary:
    def __init__(self, title: str, gloss_div: GlossDiv):
        self.title = title
        self.gloss_div = gloss_div

def json_to_object(json_data):
    gloss_def = GlossDef(
        para=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['GlossDef']['para'],
        gloss_see_also=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['GlossDef']['GlossSeeAlso']
    )
    gloss_entry = GlossEntry(
        id=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['ID'],
        sort_as=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['SortAs'],
        gloss_term=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['GlossTerm'],
        acronym=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['Acronym'],
        abbrev=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['Abbrev'],
        gloss_def=gloss_def,
        gloss_see=json_data['glossary']['GlossDiv']['GlossList']['GlossEntry']['GlossSee']
    )
    gloss_list = GlossList(gloss_entry=gloss_entry)
    gloss_div = GlossDiv(
        title=json_data['glossary']['GlossDiv']['title'],
        gloss_list=gloss_list
    )
    glossary = Glossary(
        title=json_data['glossary']['title'],
        gloss_div=gloss_div
    )
    return glossary

def read_json(file_path):
    try:
        with open(file_path, 'r') as file:
            data = json.load(file)
        return data
    except FileNotFoundError:
        print(f"Error: The file {file_path} does not exist.")
    except json.JSONDecodeError:
        print(f"Error: The file {file_path} is not a valid JSON file.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

# Example usage
if __name__ == "__main__":
    file_path = 'C:\\Users\\BAN\\.bash\\BAN-WORK-TOP\\Scripts\\glossary.json'
    json_data = read_json(file_path)
    if json_data:
        glossary_object = json_to_object(json_data)
        print(glossary_object)