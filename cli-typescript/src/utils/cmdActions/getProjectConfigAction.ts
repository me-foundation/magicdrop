import { showText } from '../display';
import { init } from '../evmUtils';

const getProjectConfigAction = async (symbol: string) => {
  symbol = symbol.toLowerCase();

  const { store } = init(symbol);

  showText(`${symbol} information retrieved successfully.`);
  console.log(JSON.stringify(store.data, null, 2));
};

export default getProjectConfigAction;
