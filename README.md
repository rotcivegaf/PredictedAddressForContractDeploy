# Mina tus direcciones precalculadas para deploy de contratos

## Address contracts

### Arthera

- Create3Factory: [0x165547bE10567d6188DA6De7fd6BdcCd34F80D60](https://explorer-test.arthera.net/address/0x165547bE10567d6188DA6De7fd6BdcCd34F80D60)
- Create3Market: [`0x0702224dc991BD1adBecAA291188f200319E28bA`](https://explorer-test.arthera.net/address/0x0702224dc991BD1adBecAA291188f200319E28bA)

### Goerli

- Create3Factory: [0x165547bE10567d6188DA6De7fd6BdcCd34F80D60](https://goerli.etherscan.io/address/0x165547be10567d6188da6de7fd6bdccd34f80d60)
- Create3Market: [`0xc54ae1172a7e671002c3bf73c8d75e54c9d2effe`](https://goerli.etherscan.io/address/0xc54ae1172a7e671002c3bf73c8d75e54c9d2effe)

## Presentacion y video

[https://github.com/rotcivegaf/PredictedAddressForContractDeploy/blob/main/Presentation.pdf](https://github.com/rotcivegaf/PredictedAddressForContractDeploy/blob/main/Presentation.pdf)

[https://youtu.be/hhe_xmOriWQ](https://youtu.be/hhe_xmOriWQ)

## Caracteristicas

- Minado de direcciones con ciertas caracteristicas
- Mint NFT que representa esta address
- Deploy el contrato
- Crear/comprar ordenes en el Create3Market
- Comprar/vender el NFT en mercados como Opensea
- Funciona en todas las cadena EVM compatible

## La idea

Crea un ERC721(NFT) que represente una direccion precalculada con cierta caracteristicas, con este NFT se puede deployar un contrato que tenga la direccion minada

Esto es util cuando quieres un contrato que por ejemplo empiece con ceros para optimizar gas en las transacciones, o que empiece con el nombre en especial como `DEAD`

Como es un NFT se puede transferir y vender o comprar en mercados como Opensea

Otra caracteristica es la posibilidad de crear una orden en el contrato Create3Market, esta orden especifica que caracteristicas debera tener el address y el rewards por hallarla. Un usuario puede minar un address con estas caracteristicas, mintear el NFT, satisfacer esta order y generar una ganancia a cambio del NFT

Como resultado se genera un mercado donde por un lado hay usuarios/protocolos que necesitan una direccion especifica para deployar sus contratos y por el otro lado mineros que generan estas address para venderlas por el reward

## Contrato Create3Factory

En la EVM(Ethereum Virtual Machine) tenemos 2 opcode para deployar un contrato `CREATE` y `CREATE2`. El address resultante del deploy es deterministica, esto quiere decir que podemos predecir esta address.

Como `CREATE2` usa el codigo del contrato para generar la address, necesitamos `CREATE3` que genera una address independientemente del codigo a deployar

Esta magia esta echa en: [https://github.com/0xsequence/create3](https://github.com/0xsequence/create3)

- `CREATE` usa `sender + nonce`
- `CREATE2` usa `sender + salt + creationCode`
- `CREATE3` usa `sender + salt + creationCode`, pero el creationCode es constante: `0x67363d3d37363d34f03d5260086018f3`

Con `CREATE3` dado una `salt` podemos asegurar un address y mintear nuestro NFT que representara esa address. Para protegernos de un ataque de front-running el `salt` es creado con un `keccak256` de [`minter address + another salt`](https://github.com/rotcivegaf/create3/blob/9e6b01e7caa8da3e90327acfd1d97dc76e8cb79f/smart-contracts/src/Create3Factory.sol#L60-L67)

### Funciones

- `reserve`: Mintea el NFT
- `deploy`: Deploya el contrato y quema el NFT

## Contrato Create3Market

Es un mercado donde un usuario que busca una address con alguna caracteristica especial puede crear una Order y otro usuario puede tomar esta Order

### Funciones

- `createOrder`: Crea una orden es el mercado

```solidity
    struct Order {
        address to;            // El que recive el NFT
        uint96 expiryToCancel; // Una fecha limite para poder cancelar la Order
        address reserveAddr;   // El address deseada
        uint40 bitsOn;         // Cada bit representa un caracter hexa deseado o no en la reserveAddr
                               // Ejemplo: Quiero un address que empiece con 0000, y en el index diez tenga un 6 y termine con CAFE
                               //     bitsOn: F02000000F(1111000000100000000000000000000000001111)
                               //     reserveAddr:     0x0000??????6?????????????????????????CAFE
        IERC20 token;          // La moneda en la que se va a pagar la oferta
        uint256 offer;         // El monto de la moneda
        address miner;         // EL minero que puede tomar la oferta(address(0) para cualquiera)
    }
```

Cuando alguien crea una Order, del otro lado, los mineros empiezan a trabajar para satisfacer la Order

Esta Order puede ser cancelada despues del `expiryToCancel` timestamp dando la chance al minero a poder encontrar la address

- `cancelOrder`: Para cancelar una Order
- `takeOrder`: Para tomar la Order, vender el NFT al creador de la Order y obtener la recompensa

### Miner

```
$ cd miner
```
```
$ npm install
```

Modifica el archivo `./miner/config.json`, por ejemplo si necesitas un address que termine en `DeaD`:

```json
{
  "factoryAdrr": "THE FACTORY ADDRESS",
  "data": {
    "sender": "YOUR ADDRESS",
    "hex": "DeaD",
    "checksum": true,
    "suffix": true
  }
}
```

```
$ node src/miner.js
```

El resultado del ejemplo:
```javascript
{
  salt: '<SALT USADO EN RESERVE>',
  senderSalt: '<SALT INTERMEDIO>',
  address: '<ADDRESS TERMINADA EN DEAD>',
  attempts: 251
}
```

Usaremos el 'salt' para reservar la direccion en el contrato Create3Factory