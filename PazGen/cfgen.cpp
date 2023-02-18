#include <iostream>
#include <fstream>
using namespace std;

class City{
    public:
        string codice;
        string citta;

        City(){
            codice="";
            citta="";
        };
};

City arrC[8223]; //array con i codici delle citta

// normalizza l'eventuale input
string norm(string s){
    for(int i=0; i<s.length(); i++){
        if(s[i]=='\'' || s[i]==' ' || s[i]=='.') {s.erase(i,1); i--;}
        else s[i] = toupper(s[i]);
    }
    return s;
}

string cog, nom, ann, cit, cf;
char ses;
int mes, gio;

void cognome(){
    int n = cog.length();
    int countC = 0;
    string aux="";
    for(int i=0; i<n; i++){
        switch (cog[i])
        {
        case 'A':
        case 'E':
        case 'I':
        case 'O':
        case 'U':
            break;
        default: aux += cog[i]; countC++;
        }
    }
    if (countC>=3) {
        cf += aux.substr(0,3);
        return;
    }
    for(int i=0; i<n; i++){
        switch (cog[i])
        {
        case 'A':
        case 'E':
        case 'I':
        case 'O':
        case 'U': aux += cog[i];
        }
    }
    if (aux.length()>=3){
        cf += aux.substr(0,3);
        return;
    }
    while (aux.length()<3) aux += 'X';
    cf += aux;
}

void nome(){
    int n = nom.length();
    int countC = 0;
    string aux="";
    for(int i=0; i<n; i++){
        switch (nom[i])
        {
        case 'A':
        case 'E':
        case 'I':
        case 'O':
        case 'U':
            break;
        default: aux += nom[i]; countC++;
        }
    }
    if (countC>3) {
        aux.erase(1,1);
        cf += aux.substr(0,3);
        return;
    }
    if (countC==3) {
        cf += aux.substr(0,3);
        return;
    }
    for(int i=0; i<n; i++){
        switch (nom[i])
        {
        case 'A':
        case 'E':
        case 'I':
        case 'O':
        case 'U': aux += nom[i];
        }
    }
    if (aux.length()>=3){
        cf += aux.substr(0,3);
        return;
    }
    while (aux.length()<3) aux += 'X';
    cf += aux;
}

void nascita(){
    string aux = "";
    string s="";
    aux += ann.substr(2,2);
    switch (mes)
    {
        case 1: aux += "A"; break;
        case 2: aux += "B"; break;
        case 3: aux += "C"; break;
        case 4: aux += "D"; break;
        case 5: aux += "E"; break;
        case 6: aux += "H"; break;
        case 7: aux += "L"; break;
        case 8: aux += "M"; break;
        case 9: aux += "P"; break;
        case 10: aux += "R"; break;
        case 11: aux += "S"; break;
        case 12: aux += "T"; break;
    } 
    if (ses == 'F' || ses == 'f') gio+=40;
    s += to_string(gio);
    if (s.length()==1) {s = '0'; s += to_string(gio);}
    aux += s;
    cf += aux;
}

void luogo(){
    string aux="";
    for(int i=0; i<8223; i++){
        if(arrC[i].citta==cit) {aux += arrC[i].codice; break;}
    }
    cf += aux;
}

void verifica(){
    string aux=cf;
    int sum=0;
    for(int i=0; i<aux.length(); i++){
        if((i+1)%2){ //dispari
            switch (aux[i])
            {
                case 'A':
                case '0': sum+=1; break;
                case 'B':
                case '1': sum+=0; break;
                case 'C':
                case '2': sum+=5; break;
                case 'D':
                case '3': sum+=7; break;
                case 'E':
                case '4': sum+=9; break;
                case 'F':
                case '5': sum+=13; break;
                case 'G':
                case '6': sum+=15; break;
                case 'H':
                case '7': sum+=17; break;
                case 'I':
                case '8': sum+=19; break;
                case 'J':
                case '9': sum+=21; break;
                case 'K': sum+=2; break;
                case 'L': sum+=4; break;
                case 'M': sum+=18; break;
                case 'N': sum+=20; break;
                case 'O': sum+=11; break;
                case 'P': sum+=3; break;
                case 'Q': sum+=6; break;
                case 'R': sum+=8; break;
                case 'S': sum+=12; break;
                case 'T': sum+=14; break;
                case 'U': sum+=16; break;
                case 'V': sum+=10; break;
                case 'W': sum+=22; break;
                case 'X': sum+=25; break;
                case 'Y': sum+=24; break;
                case 'Z': sum+=23; break;
            }
        }
        else{ //pari
            switch (aux[i])
            {
                case 'A':
                case '0': sum+=0; break;
                case 'B':
                case '1': sum+=1; break;
                case 'C':
                case '2': sum+=2; break;
                case 'D':
                case '3': sum+=3; break;
                case 'E':
                case '4': sum+=4; break;
                case 'F':
                case '5': sum+=5; break;
                case 'G':
                case '6': sum+=6; break;
                case 'H':
                case '7': sum+=7; break;
                case 'I':
                case '8': sum+=8; break;
                case 'J':
                case '9': sum+=9; break;
                case 'K': sum+=10; break;
                case 'L': sum+=11; break;
                case 'M': sum+=12; break;
                case 'N': sum+=13; break;
                case 'O': sum+=14; break;
                case 'P': sum+=15; break;
                case 'Q': sum+=16; break;
                case 'R': sum+=17; break;
                case 'S': sum+=18; break;
                case 'T': sum+=19; break;
                case 'U': sum+=20; break;
                case 'V': sum+=21; break;
                case 'W': sum+=22; break;
                case 'X': sum+=23; break;
                case 'Y': sum+=24; break;
                case 'Z': sum+=25; break;
            }
        }
    }
    sum = sum%26;
    switch (sum)
    {
        case 0: cf += 'A'; break;
        case 1: cf += 'B'; break;
        case 2: cf += 'C'; break;
        case 3: cf += 'D'; break;
        case 4: cf += 'E'; break;
        case 5: cf += 'F'; break;
        case 6: cf += 'G'; break;
        case 7: cf += 'H'; break;
        case 8: cf += 'I'; break;
        case 9: cf += 'J'; break;
        case 10: cf += 'K'; break;
        case 11: cf += 'L'; break;
        case 12: cf += 'M'; break;
        case 13: cf += 'N'; break;
        case 14: cf += 'O'; break;
        case 15: cf += 'P'; break;
        case 16: cf += 'Q'; break;
        case 17: cf += 'R'; break;
        case 18: cf += 'S'; break;
        case 19: cf += 'T'; break;
        case 20: cf += 'U'; break;
        case 21: cf += 'V'; break;
        case 22: cf += 'W'; break;
        case 23: cf += 'X'; break;
        case 24: cf += 'Y'; break;
        case 25: cf += 'Z'; break;
    }
}

void code(){
    cf = "";
    cognome();
    nome();
    nascita();
    luogo();
    verifica();
}