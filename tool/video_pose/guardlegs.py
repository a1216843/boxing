"""가드 자세의 다리 각도와 몸 비율을 잰다.

usage: guardlegs.py <poses.npz> [...]
가드 프레임 = 두 손목이 코에서 몸통 길이의 0.75배 안, 상체 기울기 8° 미만, 골반 속도 낮음.
"""
import sys
import numpy as np
sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from body import *
LKN,RKN=25,26
for path in sys.argv[1:]:
    w,t,fps,img=load(path)
    sh=(w[:,LSH]+w[:,RSH])/2; hip=(w[:,LHIP]+w[:,RHIP])/2
    L=np.nanmedian(np.linalg.norm(sh-hip,axis=1))
    nose=w[:,NOSE]
    near=(np.linalg.norm(w[:,LWR]-nose,axis=1)<0.75*L)&(np.linalg.norm(w[:,RWR]-nose,axis=1)<0.75*L)
    tr=sh-hip; roll=np.degrees(np.arctan2(tr[:,0],tr[:,1]))
    sp=np.r_[0,np.linalg.norm(np.diff(hip,axis=0),axis=1)]*fps/L
    ok=near&(np.abs(roll)<8)&(sp<0.5)
    def ang(a,b,c):
        u=w[:,a]-w[:,b]; v=w[:,c]-w[:,b]
        return np.degrees(np.arccos(np.sum(u*v,1)/np.linalg.norm(u,axis=1)/np.linalg.norm(v,axis=1)))
    kl=ang(LHIP,LKN,LANK); kr=ang(RHIP,RKN,RANK)
    leg=(np.linalg.norm(w[:,LHIP]-w[:,LKN],axis=1)+np.linalg.norm(w[:,LKN]-w[:,LANK],axis=1)+np.linalg.norm(w[:,RHIP]-w[:,RKN],axis=1)+np.linalg.norm(w[:,RKN]-w[:,RANK],axis=1))/2
    ank=np.linalg.norm(w[:,LANK]-w[:,RANK],axis=1)
    shw=np.linalg.norm(w[:,LSH]-w[:,RSH],axis=1)
    hh=(hip[:,1]-(w[:,LANK,1]+w[:,RANK,1])/2)
    thigh=np.linalg.norm(w[:,LHIP]-w[:,LKN],axis=1)
    pitch=np.degrees(np.arctan2(tr[:,2],tr[:,1]))
    print(path.rsplit('/',1)[-1], 'n',ok.sum(), 'kneeL %.0f kneeR %.0f'%(np.nanmedian(kl[ok]),np.nanmedian(kr[ok])),
      'stance/shoulderW %.2f'%np.nanmedian(ank[ok]/shw[ok]), 'stance/leg %.2f'%np.nanmedian(ank[ok]/leg[ok]),
      'hipH/leg %.2f'%np.nanmedian(hh[ok]/leg[ok]), 'leg/trunk %.2f'%np.nanmedian(leg[ok]/L), 'thigh/trunk %.2f'%np.nanmedian(thigh[ok]/L), 'shW/trunk %.2f'%np.nanmedian(shw[ok]/L))
