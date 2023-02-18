#include "cfgen.cpp"
#include <cstdlib>
#include <ctime>

string nomiMarr[331];
string nomiFarr[394];
string cognoarr[21738];

string minu(string s){
    for(int i=0; i<s.length(); i++){
        if(s[i]=='\'' || s[i]==' ' || s[i]=='.') continue;
        s[i]=tolower(s[i]);
    }
    return s;
}

string pickNomM(){
    return nomiMarr[rand()%331];
}

string pickNomF(){
    return nomiFarr[rand()%394];
}

string pickCog(){
    return cognoarr[rand()%21738];
}

string pickCity(){
    return arrC[rand()%8223].citta;
}

string pickData(){
    string aux;
    int annoData = 1940 + rand()%78;
    aux = to_string(annoData);
    ann = aux;
    aux += '-';
    int meseData = 1+rand()%12;
    mes = meseData;
    aux += to_string(meseData);
    aux += '-';
    int giornoData;
    switch(meseData)
    {
        case 1:
        case 3:
        case 5:
        case 7:
        case 8:
        case 10:
        case 12:
            giornoData=1+rand()%31;
            gio = giornoData; break;
        case 2:
            giornoData=1+rand()%28;
            gio = giornoData; break;
        case 4:
        case 6:
        case 9:
        case 11:
            giornoData=1+rand()%30;
            gio = giornoData; break;
    }
    aux += to_string(giornoData);
    return aux;
}

string reca(){
    string s="";
    int r;
    s+='3';
    for(int i=0; i<9; i++){
        r=rand()%10;
        s+=to_string(r);
    }
    return s;
}

bool refind(string s, int x){
    for(int i=0; i<s.length(); i++){
        if(int(s[i])==x) return true;
    }
    return false;
}

bool ok(string s){
    int c[6] = {-15456, -15448, -15447, -15438, -15431};
    for(int i=0; i<6; i++){
        if(refind(s, c[i])) return false;
    }
    if(int(s[s.length()-1]) == 39) return false;
    return true;
}

class Pazienti{
    public:
        string codfisc, cognome, nome, data, recap, email;
        char gen;
        float sconto;

        Pazienti(){
            recap = reca();
            cit = pickCity();
            email="NULL";
            sconto = 0;
            cognome=pickCog();
            while(!ok(cognome)) cognome=pickCog();
            cog = norm(cognome);
            switch (rand()%2)
            {
                case 0: gen = 'M'; break;
                case 1: gen = 'F';
            }
            ses = gen;
            if (gen == 'M') {
                nome = pickNomM();
                while(!ok(nome)) nome=pickNomM();
            }
            else {
                nome = pickNomF();
                while(!ok(nome)) nome=pickNomF();
            }
            nom = norm(nome);
            if(!(rand()%4)){
                email = minu(norm(nome)) + '.' + minu(norm(cognome));
                switch(rand()%5){
                    case 0: email += "@gmail.com"; break;
                    case 1: email += "@outlook.it"; break;
                    case 2: email += "@virgilio.it"; break;
                    case 3: email += "@alice.it"; break;
                    case 4: email += "@pec.it"; break;
                }
            }
            if(!(rand()%3)) sconto += (1+rand()%6)*0.05;
            data = pickData();
            code();
            codfisc = cf;
        }

        ostream& print(ostream& os){
            os << "(`" << codfisc << "`, `" << cognome << "`, `" << nome << "`, `" << data << "`, `" << gen << "`, `" << recap << "`, `" << email << "`, `" << sconto << "`),\n";
            return os;
        }
};

ostream& operator<<(ostream& os, Pazienti& p){
    return p.print(os);
}