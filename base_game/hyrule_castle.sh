#!/bin/bash

b_result=1
over=1
floor=1
if [[ $1 == "-B" ]]; then #debugging purposes
    floor=10
fi

get_char () {
    char_pos=$1
    pos=0
    name=$3

    while IFS="\n" read; do
        if [[ $pos -eq $char_pos ]]; then
            echo $REPLY > $name.stt
            echo $name.stt
        fi
        pos=$(($pos+1))
    done < $2
}

#Randomly generates a rarity tier, rarity tiers rates are copied from project subject

rarity_num() {
    rarity=$(($RANDOM%100+1))

    if [[ $rarity -le 50 ]]; then
        echo 1
    elif [[ $rarity -le 80 ]]; then
        echo 2
    elif [[ $rarity -le 95 ]]; then
        echo 3
    elif [[ $rarity -le 99 ]]; then
        echo 4
    elif [[ $rarity -eq 100 ]]; then
        echo 5
    fi
}

#has to calculate number of elements corresponding to a given rarity tier
#takes corresponding file in parameter for future proofing

#Since rarity is the last parameter I only to cut the last 2 bytes
#of a line to get it, hence ~tail -c2 in the if

get_tiernum (){
    tier=$1
    count=0

    while IFS="\n" read line; do
        if [[ $(echo $line | tail -c2) -eq $tier ]]; then
            count=$(($count+1))
        fi
    done < $2
    echo $count
}


generate_rand (){
    rarity_tier=$(rarity_num)                  #rarity tier in which to pick monster
    tiernum=$(get_tiernum $rarity_tier $1)  #number of monsters in that tier
    seed=$(($RANDOM%$tiernum+1))               #which monster to pick in that tier
    fl=0
    count=0

    while IFS="," read id name dump && [[ $count -ne $seed ]]; do
        if [[ fl -eq 1 ]]; then     #avoids bad comparison with header line
            if [[ $(echo $dump | tail -c2) -eq $rarity_tier ]]; then
                count=$(($count+1))
            fi
            if [[ $count -eq $seed ]]; then
                echo $(get_char $id $1 $name)
            fi
        else
            fl=1
        fi
    done < $1
}

#generates .stt file and returns name for further use once we know precisely where to find wanted char

#generates stats from given .stt file, made two different functions for names to be different, and usable outside of genera_xxxxstats

generate_playerstats (){
    IFS="," read p_id p_name p_hp p_mp p_str p_int p_def p_res p_spd p_luck p_race p_class p_rarity < $1
}

generate_enemystats (){
    IFS="," read m_id m_name m_hp m_mp m_str m_int m_def m_res m_spd m_luck m_race m_class m_rarity < $1
}


################################################
#Generating player .stt file and stats

player=$(generate_rand "./csv/players.csv")
generate_playerstats $player


################################################


#base attack function, str is attacker strength, o_hp is target hp
#$1 is attacker str $2 is receiver hp $3 is attacker name
#n_hp is new hp, the value to be returned
#dmg is total dmg value, might be used for display stuff
atk (){
    n_hp=$(($2-$1))
    dmg=$(($2-$n_hp))
    if [[ $n_hp -lt 0 ]]; then
	    n_hp=0
    fi
    echo $n_hp
}

#base heal function, $1 is current healer hp, $2 is healer max hp
#h_hp is hp after healing, value to be returned

heal (){

    h_hp=$(($2/2+$1)) 
    if [[ $h_hp -gt $2 ]]; then    #make sure player can't have more hp than max
	    h_hp=$2
    fi
    echo $h_hp
}

#second function fetches whole line and writes it into a temporary file
#returns file name for further use

main_floors (){
    echo $'=======================\nYou did not falter against strife, but pride shall wait.\nFor another challenge awaits thee.\n=======================\n\nNow step on to FLOOR' $1$'\n===================='
}

set_floor (){
    if [[ $floor -eq 1 ]]; then
	    cat welcome.txt
    elif [[ $floor -lt 10 ]]; then
	    main_floors $floor
    else
        echo $'====================\nClench your fists, what is to come now nothing short of ungodly powerful. You have done so well so far but you have to face your destiny now\n====================\nYou step of the FINAL FLOOR'
    fi
}

#might be used to secure generate_rand, unused atm

check_type(){
    type=$(echo $1 | tr [:upper:] [:lower:])
    if [[ $type == "bosses" ]] || [[ $type == "boss" ]]; then
	echo "bosses"
    elif [[ $type == "players" ]] || [[ $type == "player" ]]; then
	echo "players"
    elif [[ $type == "classes" ]] || [[ $type == "class" ]]; then
	echo "classes"
    elif [[ $type == "enemies" ]] || [[ $type == "enemy" ]]; then
	echo "enemies"
    else
	echo "err_type"
    fi
}

#main enemy generating function
#rarity sum returns a rarity tier, randomly choosen according to subject rates
#get_tiernum returns the number of entries for a given rarity tier
#generate_enemy will gather all those results to pick a random enemy
#within the boundaries set by the two previous functions

#while loop will read through enemies.csv, and return a full character
#stat file, geenrated by get_char
#loop stops once count is equal to seed (which monster to pick in a tier)

#recently changed to generate given type, should only be used with
#bosses players enemies and classes

#action sorting function to avoid clogging in main loop
get_action (){
    key=$1

    if [[ $key == 1 ]] || [[ $key == "&" ]]; then
        action=1
        m_currenthp=$(atk $p_str $m_currenthp $p_name)
        echo $'\n====================\n\nYou chose to attack\n'
    elif [[ $key == 2 ]] || [[ $key == "é" ]]; then
        echo $'\n====================\n\nYou chose to heal'
        action=1
        p_currenthp=$(heal $p_currenthp $p_hp)
    else
        echo $'\nWrong input: please choose one of the displayed action:\n Press 1/& for attack, 2/é for heal\n'
    fi
    if [[ $action == 1 ]] && [[ $m_currenthp -gt 0 ]]; then
        p_currenthp=$(atk $m_str $p_currenthp $m_name)
        echo $'\n'$m_name $'strikes\n\n===================='
    fi
    action=0
}

battle_loop () {
    if [[ $floor -lt 10 ]]; then
        o_file=$(generate_rand "./csv/enemies.csv")
    else
        o_file=$(generate_rand "./csv/bosses.csv")
    fi

    generate_enemystats $o_file
    p_currenthp=$p_hp
    m_currenthp=$m_hp

    status=0                                                                      #will be used to keep track of battle state: is one of the parties dead or not
    action=0                                                                      #will be used to keep track of if player has entered a valid command
    
    while [[ $status -eq 0 ]]; do
	    echo $'\n'$p_name$':' $p_currenthp$'HP\n'$m_name$':' $m_currenthp$'HP\n'
	    read -sn1 -p $'What will your next move be?\n1.Attack 2.Heal\n' input
	    get_action $input
        action=0
	    if [[ $p_currenthp -eq 0 ]] || [[ $m_currenthp -eq 0 ]]; then            #Assigns a value to status if one of the hps are 0, rest will decide who wins depending on status value
	        status=$(($p_currenthp-$m_currenthp))                                #status > 0 = player won;   status < 0 = player lost 
	    fi
    done
    if [[ $status -gt 0 ]]; then
	    echo $'\nSuccess!!'
        if [[ $floor -lt 10 ]]; then
            read -sn1 -p "Press any key to continue"
        fi
        b_result=1
    else
        b_result=0
    fi
}


while [[ $floor -le 10 ]] && [[ $b_result -eq 1 ]]; do
    clear
    set_floor $floor
    battle_loop $player $floor
    floor=$(($floor+1))
done
clear
if [[ $b_result -eq 0 ]]; then
    echo $'Another hero falls to the clutches of evil...\n\n'
else
    echo $'Congratulations, by your hand, tommorow at least shall be a morning without the stench of fear. Thank you hero...\n\n'
fi

read -sn1 -p "Press any key to quit"
clear

rm *.stt

#while [[ $over -eq 0 ]] && [[ $status -eq -1 ]]; do
