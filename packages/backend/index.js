require('dotenv-flow').config();

const express = require('express');
const Render = require('./lib/render');
const Validate = require('./lib/validate');
const { Renderers, Splice, getProvider } = require('@splicenft/common');

const app = express();
const port = process.env.PORT || 5999;

const GRAYSCALE_COLORS = [
  [20, 30, 40],
  [80, 80, 80],
  [100, 100, 100],
  [150, 150, 150],
  [175, 175, 175],
  [200, 200, 200],
  [220, 220, 220],
  [250, 250, 250]
];
app.get('/render/:algo', (req, res) => {
  const renderer = Renderers[req.params.algo];
  if (!renderer) return res.status(404).send('algorithm not found');
  try {
    Render(
      renderer,
      {
        colors: GRAYSCALE_COLORS,
        dim: { w: 1500, h: 500 }
      },
      (err, buffer) => {
        if (err) {
          console.error(err);
          return res.status(500).end();
        }
        res.set('Content-Type', 'image/png');
        res.status(200);
        res.send(buffer);
      }
    );
  } catch (e) {
    console.error(e);
    res.status(500).end();
  }
});

app.get('/validate/:mintjob', async (req, res) => {
  const mintJobId = req.params.mintjob;
  const { provider, signer } = getProvider('http://localhost:8545', {
    infuraKey: process.env.INFURA_KEY,
    privateKey: process.env.DEPLOYER_PRIVATEKEY
  });

  const splice = Splice.from(process.env.SPLICE_CONTRACT_ADDRESS, signer);
  const job = await Validate(mintJobId, splice);
  await res.send(job);
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
