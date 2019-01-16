
template <class Type>
vector<Type> predNFun(dataSet<Type> &dat, confSet &conf, paraSet<Type> &par, array<Type> &logN, array<Type> &logF, int i){
  int stateDimN=logN.dim[0];

  vector<Type> predN(stateDimN); 
  Type thisSSB=Type(0);
  if(conf.stockRecruitmentModelCode==0){ // straight RW 
    predN(0)=logN(0,i-1);
  }else if(conf.stockRecruitmentModelCode==-1){ // AR1 (on log-scale)
    Type autocor = 2.0 / (1.0 + exp(-par.rec_logb(0))) - 1.0;
    predN(0) = par.rec_loga(0) + autocor * (logN(0,i-1) - par.rec_loga(0));
  }else{
    if((i-conf.minAge)>=0){
      thisSSB=ssbi(dat,conf,logN,logF,i-conf.minAge);
    }else{
      thisSSB=ssbi(dat,conf,logN,logF,0); // use first in beginning       
    } 
    if(conf.stockRecruitmentModelCode==1){//ricker
      predN(0)=par.rec_loga(0)+log(thisSSB)-exp(par.rec_logb(0))*thisSSB;
    }else if(conf.stockRecruitmentModelCode==2){//BH
      predN(0)=par.rec_loga(0)+log(thisSSB)-log(1.0+exp(par.rec_logb(0))*thisSSB);
    }else if(conf.stockRecruitmentModelCode == 3){ //Hockey stick
      Type log_level = par.rec_loga(0);
      Type log_blim = par.rec_logb(0);
      Type a = thisSSB - exp(log_blim);
      Type b = 0.0;
      Type cut = 0.5 * (a+b+CppAD::abs(a-b)); // max(a,b)
      predN(0) = log_level - log_blim + log(thisSSB-cut);
    }else if(conf.stockRecruitmentModelCode == 4){ //Bent hypoerbola
      Type gamma = 20.0 * 20.0 / 4.0;
      Type Sstar = exp(par.rec_loga(0));
      predN(0) = par.rec_logb(0) +
	log(thisSSB + sqrt(Sstar*Sstar + gamma) - sqrt(pow(thisSSB-Sstar,2) + gamma));
    }else{
      error("SR model code not recognized");
    }
  }
  
    for(int j=1; j<stateDimN; ++j){
      if(conf.keyLogFsta(0,j-1)>(-1)){
        predN(j)=logN(j-1,i-1)-exp(logF(conf.keyLogFsta(0,j-1),i-1))-dat.natMor(i-1,j-1); 
      }else{
        predN(j)=logN(j-1,i-1)-dat.natMor(i-1,j-1); 
      }
    }  
    if(conf.maxAgePlusGroup==1){
      predN(stateDimN-1)=log(exp(logN(stateDimN-2,i-1)-exp(logF(conf.keyLogFsta(0,stateDimN-2),i-1))-dat.natMor(i-1,stateDimN-2))+
                             exp(logN(stateDimN-1,i-1)-exp(logF(conf.keyLogFsta(0,stateDimN-1),i-1))-dat.natMor(i-1,stateDimN-1))); 
    }
  return predN;  
}
