import express from 'express';
import { Level } from 'level';

const app = express();
const port = 3000;

const db = new Level('/data/leveldb', { valueEncoding: 'json' });

app.use(express.json());

app.get('/', (req, res) => {
  res.send('LevelDB API is up and running!');
});

db.open()
  .then(() => {
    console.log('LevelDB is open');

    app.post('/set', async (req, res) => {
      const { key, value } = req.body;
      try {
        await db.put(key, value);
        res.json({ status: 'success', key, value });
      } catch (err) {
        console.error('DB error:', err);
        res.status(500).json({ error: 'Error writing to DB' });
      }
    });

    app.get('/get/:key', async (req, res) => {
      const key = req.params.key;
      try {
        const value = await db.get(key);
        res.json({ key, value });
      } catch (err) {
        if (err.notFound) {
          res.status(404).json({ error: 'Key not found' });
        } else {
          console.error('DB error:', err);
          res.status(500).json({ error: 'Error reading from DB' });
        }
      }
    });

    app.listen(port, () => {
      console.log(`Server running on port ${port}`);
    });
  })
  .catch(err => {
    console.error('Failed to open DB:', err);
  });
