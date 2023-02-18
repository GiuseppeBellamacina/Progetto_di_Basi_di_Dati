#include "pazgen.cpp"
#define DIM 2000

int main(){
    srand(time(0));
    string s;
    int iter=0;
    fstream nomicitta, nomiM, nomiF, cognomi;
    fstream outputcf, output;
    nomicitta.open("citta.txt", fstream::in);
    // riempio l'array delle città
    {
        while (getline(nomicitta,s))
        {   
            s=norm(s);
            arrC[iter].codice=s.substr(0,4);
            s.erase(0,5);
            arrC[iter].citta=s;
            iter++;
        }
        nomicitta.close();
    }
    iter=0;
    nomiM.open("nomiM.txt", fstream::in);
    // riempio l'array dei nomi maschili
    {
        while(getline(nomiM,s))
        {
            nomiMarr[iter]=s;
            iter++;
        }
        nomiM.close();
    }
    iter=0;
    nomiF.open("nomiF.txt", fstream::in);
    // riempio l'array dei nomi femminili
    {
        while(getline(nomiF,s))
        {
            nomiFarr[iter]=s;
            iter++;
        }
        nomiF.close();
    }
    iter=0;
    cognomi.open("cognomi.txt", fstream::in);
    // riempio l'array dei cognomi
    {
        while(getline(cognomi,s))
        {
            cognoarr[iter]=s;
            iter++;
        }
        cognomi.close();
    }

    outputcf.open("outputcf.txt", fstream::out | fstream::app);
    output.open("output.txt", fstream::out | fstream::app);
    Pazienti arr[DIM];
    output << "INSERT INTO `pazienti` ";
    output << "(`CF`, `Cognome`, `Nome`, `Data_Nascita`, `Genere`, `Recapito`, `E-mail`, `Sconto`) VALUES\n";
    for(int i=0; i<DIM; i++){
        cout << arr[i];
        output << arr[i];
        outputcf << arr[i].codfisc << endl;
    }
    outputcf.close();
    output.close();
}
