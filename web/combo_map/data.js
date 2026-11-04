// tool/combo_map_export_test.dart 로 만든 파일. 직접 고치지 말 것.
const DATA = {
 "moves": [
  {
   "id": "jab",
   "type": "jab",
   "defense": false,
   "special": false,
   "nameO": "잽",
   "nameS": "잽",
   "compat": {
    "lead": 0.6,
    "center": 1.0,
    "rear": 0.9
   },
   "result": "center",
   "low": false,
   "freq": 1.3
  },
  {
   "id": "cross",
   "type": "straight",
   "defense": false,
   "special": false,
   "nameO": "투",
   "nameS": "투",
   "compat": {
    "lead": 0.15,
    "center": 1.0,
    "rear": 1.0
   },
   "result": "lead",
   "low": false,
   "freq": 1.3
  },
  {
   "id": "leadHook",
   "type": "hook",
   "defense": false,
   "special": false,
   "nameO": "레프트 훅",
   "nameS": "라이트 훅",
   "compat": {
    "lead": 1.0,
    "center": 0.6,
    "rear": 0.1
   },
   "result": "rear",
   "low": false,
   "freq": 1.0
  },
  {
   "id": "rearHook",
   "type": "hook",
   "defense": false,
   "special": false,
   "nameO": "라이트 훅",
   "nameS": "레프트 훅",
   "compat": {
    "lead": 0.0,
    "center": 0.35,
    "rear": 1.0
   },
   "result": "lead",
   "low": false,
   "freq": 0.6
  },
  {
   "id": "leadUpper",
   "type": "uppercut",
   "defense": false,
   "special": false,
   "nameO": "레프트 어퍼",
   "nameS": "라이트 어퍼",
   "compat": {
    "lead": 1.0,
    "center": 0.4,
    "rear": 0.1
   },
   "result": "rear",
   "low": false,
   "freq": 0.8
  },
  {
   "id": "rearUpper",
   "type": "uppercut",
   "defense": false,
   "special": false,
   "nameO": "라이트 어퍼",
   "nameS": "레프트 어퍼",
   "compat": {
    "lead": 0.0,
    "center": 0.5,
    "rear": 1.0
   },
   "result": "lead",
   "low": false,
   "freq": 0.8
  },
  {
   "id": "leadBody",
   "type": "body",
   "defense": false,
   "special": false,
   "nameO": "레프트 바디",
   "nameS": "라이트 바디",
   "compat": {
    "lead": 1.0,
    "center": 0.6,
    "rear": 0.1
   },
   "result": "rear",
   "low": true,
   "freq": 1.0
  },
  {
   "id": "rearBody",
   "type": "body",
   "defense": false,
   "special": false,
   "nameO": "라이트 바디",
   "nameS": "레프트 바디",
   "compat": {
    "lead": 0.1,
    "center": 1.0,
    "rear": 1.0
   },
   "result": "lead",
   "low": true,
   "freq": 1.0
  },
  {
   "id": "jabBody",
   "type": "body",
   "defense": false,
   "special": false,
   "nameO": "바디 잽",
   "nameS": "바디 잽",
   "compat": {
    "lead": 0.5,
    "center": 1.0,
    "rear": 0.8
   },
   "result": "center",
   "low": true,
   "freq": 0.5
  },
  {
   "id": "slipLead",
   "type": "slip",
   "defense": true,
   "special": false,
   "nameO": "레프트 슬립",
   "nameS": "라이트 슬립",
   "compat": {
    "lead": 0.2,
    "center": 1.0,
    "rear": 0.8
   },
   "result": "lead",
   "low": false,
   "freq": 1.0
  },
  {
   "id": "slipRear",
   "type": "slip",
   "defense": true,
   "special": false,
   "nameO": "라이트 슬립",
   "nameS": "레프트 슬립",
   "compat": {
    "lead": 0.8,
    "center": 1.0,
    "rear": 0.2
   },
   "result": "rear",
   "low": false,
   "freq": 1.0
  },
  {
   "id": "duckLead",
   "type": "duck",
   "defense": true,
   "special": false,
   "nameO": "레프트 더킹",
   "nameS": "라이트 더킹",
   "compat": {
    "lead": 0.2,
    "center": 1.0,
    "rear": 0.8
   },
   "result": "lead",
   "low": true,
   "freq": 0.8
  },
  {
   "id": "duckRear",
   "type": "duck",
   "defense": true,
   "special": false,
   "nameO": "라이트 더킹",
   "nameS": "레프트 더킹",
   "compat": {
    "lead": 0.8,
    "center": 1.0,
    "rear": 0.2
   },
   "result": "rear",
   "low": true,
   "freq": 0.8
  },
  {
   "id": "weaveLead",
   "type": "weave",
   "defense": true,
   "special": false,
   "nameO": "레프트 위빙",
   "nameS": "라이트 위빙",
   "compat": {
    "lead": 0.2,
    "center": 0.9,
    "rear": 1.0
   },
   "result": "lead",
   "low": true,
   "freq": 0.7
  },
  {
   "id": "weaveRear",
   "type": "weave",
   "defense": true,
   "special": false,
   "nameO": "라이트 위빙",
   "nameS": "레프트 위빙",
   "compat": {
    "lead": 1.0,
    "center": 0.9,
    "rear": 0.2
   },
   "result": "rear",
   "low": true,
   "freq": 0.7
  },
  {
   "id": "pullBack",
   "type": "pull",
   "defense": true,
   "special": false,
   "nameO": "스웨이",
   "nameS": "스웨이",
   "compat": {
    "lead": 0.8,
    "center": 1.0,
    "rear": 0.2
   },
   "result": "rear",
   "low": false,
   "freq": 0.6
  },
  {
   "id": "backStep",
   "type": "step",
   "defense": true,
   "special": false,
   "nameO": "백스텝",
   "nameS": "백스텝",
   "compat": {
    "lead": 0.7,
    "center": 0.7,
    "rear": 0.7
   },
   "result": "center",
   "low": false,
   "freq": 0.4
  },
  {
   "id": "jumpHook",
   "type": "hook",
   "defense": false,
   "special": true,
   "nameO": "점프 훅",
   "nameS": "점프 훅",
   "compat": {
    "lead": 0.4,
    "center": 1.0,
    "rear": 0.9
   },
   "result": "rear",
   "low": false,
   "freq": 0.7
  },
  {
   "id": "checkHook",
   "type": "hook",
   "defense": false,
   "special": true,
   "nameO": "체크 훅",
   "nameS": "체크 훅",
   "compat": {
    "lead": 1.0,
    "center": 0.7,
    "rear": 0.1
   },
   "result": "center",
   "low": false,
   "freq": 0.8
  },
  {
   "id": "overhand",
   "type": "overhand",
   "defense": false,
   "special": true,
   "nameO": "오버핸드 훅",
   "nameS": "오버핸드 훅",
   "compat": {
    "lead": 0.1,
    "center": 0.8,
    "rear": 1.0
   },
   "result": "lead",
   "low": false,
   "freq": 0.8
  }
 ],
 "bonus": {
  "jab>cross": 2.2,
  "cross>leadHook": 2.0,
  "cross>leadUpper": 1.3,
  "cross>leadBody": 1.3,
  "leadHook>cross": 1.8,
  "leadHook>rearUpper": 1.4,
  "leadBody>leadHook": 6.0,
  "leadUpper>leadHook": 4.0,
  "rearUpper>leadHook": 1.8,
  "rearBody>leadHook": 1.5,
  "slipLead>leadHook": 1.5,
  "slipLead>leadUpper": 1.5,
  "slipRear>cross": 1.5,
  "slipRear>rearUpper": 1.6,
  "duckLead>leadUpper": 1.6,
  "duckLead>leadHook": 1.5,
  "duckRear>rearUpper": 1.6,
  "duckRear>cross": 1.3,
  "weaveLead>leadHook": 1.5,
  "weaveRear>cross": 1.5,
  "pullBack>cross": 3.0,
  "backStep>jab": 2.0,
  "jab>jumpHook": 1.4,
  "duckLead>jumpHook": 2.0,
  "duckRear>jumpHook": 1.6,
  "jumpHook>cross": 1.8,
  "cross>checkHook": 2.0,
  "rearUpper>checkHook": 1.5,
  "slipLead>checkHook": 1.5,
  "jab>overhand": 1.6,
  "slipRear>overhand": 2.0,
  "weaveRear>overhand": 1.8,
  "duckRear>overhand": 1.5,
  "overhand>leadHook": 2.0
 },
 "levels": {
  "beginner": {
   "excluded": [
    "rearHook",
    "jabBody",
    "duckLead",
    "duckRear",
    "weaveLead",
    "weaveRear",
    "jumpHook",
    "checkHook",
    "overhand"
   ],
   "maxDefenses": 1,
   "defenseRate": 0.5,
   "lengthWeights": [
    0.2,
    0.45,
    0.35
   ],
   "lowRate": 0.35,
   "maxLow": 1,
   "levelSwitch": 1.0,
   "pairEmphasis": 1.6,
   "variety": 1.0,
   "specialRate": 1.0,
   "maxSpecials": 0
  },
  "intermediate": {
   "excluded": [
    "jumpHook",
    "checkHook",
    "overhand"
   ],
   "maxDefenses": 2,
   "defenseRate": 0.8,
   "lengthWeights": [
    0.05,
    0.25,
    0.35,
    0.25,
    0.1
   ],
   "lowRate": 1.3,
   "maxLow": 3,
   "levelSwitch": 1.8,
   "pairEmphasis": 0.8,
   "variety": 0.55,
   "specialRate": 1.0,
   "maxSpecials": 0
  },
  "advanced": {
   "excluded": [],
   "maxDefenses": 2,
   "defenseRate": 1.0,
   "lengthWeights": [
    0.02,
    0.1,
    0.24,
    0.28,
    0.22,
    0.14
   ],
   "lowRate": 1.2,
   "maxLow": 3,
   "levelSwitch": 1.6,
   "pairEmphasis": 0.8,
   "variety": 0.55,
   "specialRate": 1.3,
   "maxSpecials": 2
  }
 }
};
