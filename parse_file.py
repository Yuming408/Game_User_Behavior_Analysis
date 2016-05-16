__author__ = 'yumingfang'
import glob

def process_file(infile, outfile):

    for line in infile:
        line = line.strip()
        line = line

        # Skip whitespace at the beginning
        if line == "" or line.find("{") > -1:
            continue

        # Stop at the first '}'
        if line == "}":
            break

        # strip start and end stuff
        start = line.find('"')
        end = line.rfind('"')

        line = line[start+1:end]

        # parts fields
        # 1 - query time
        # 3 - avatar
        # 4 - guild
        # 5 - level
        # 6 - race
        # 7 - class
        # 8 - zone
        parts = [x.strip() for x in line.split(",")]

        if not valid(parts):
            continue

        # Set a sentinel value for no guild
        if parts[4] == "":
            parts[4] = "-1"

        # Write output line
        outfile.write("{0},{1},{2},{3},{4},{5},{6}\n".format(
            parts[1], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]))

def valid(parts):
    # Something is wrong with the line, either formatting or garbage data
    if len(parts) < 8:
        return False

    # Validate Avatar ID
    if int(parts[3]) < 1:
        return False

    # Validate Guild
    if parts[4] != "" and (int(parts[4]) < 1 or int(parts[4]) > 513):
        return False

    # Validate Level
    if int(parts[5]) < 1 or int(parts[5]) > 80:
        return False

    # Validate Race
    if parts[6] not in ["Blood Elf", "Orc", "Tauren", "Troll", "Undead"]:
        return False

    # Validate Class
    if parts[7] not in ["Death Knight", "Druid", "Hunter", "Mage",
                        "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"]:
        return False

    return True

def main():
    files = glob.glob("200*/*/*")
    outfile = open("user_table", "w")

    outfile.write("query_time, avatar_id, guild, level, race, class, zone\n")

    for f in files:
        infile = open(f)
        process_file(infile, outfile)
        infile.close()

    outfile.close()

main()
