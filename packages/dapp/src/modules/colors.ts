import { RGB, Transfer } from '@splicenft/common';
import axios from 'axios';

export default async function getDominantColors(
  chainId: number | string,
  collection: string,
  tokenId: string
): Promise<RGB[]> {
  const url = `${process.env.REACT_APP_VALIDATOR_BASEURL}/colors/${chainId}/${collection}/${tokenId}`;
  try {
    const { colors } = await (
      await axios.get<Transfer.ColorsResponse>(url)
    ).data;
    return colors.map((c) => c.rgb);
  } catch (e: any) {
    throw new Error(`couldnt get image colors: ${e.message}`);
  }
}
