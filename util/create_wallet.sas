%macro fdx_mywallet(user=,pass=);

%let basedir=%sysget(_BASEDIR);
%include "&basedir./macros/sas_wallet.sas";

%sas_wallet(create);
%sas_wallet(put,WS_USER,&user);
%sas_wallet(put,WS_PASSWORD,&pass);

%mend fdx_mywallet;
