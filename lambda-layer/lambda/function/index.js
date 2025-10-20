import _ from 'lodash';
import axios from 'axios';
import { format, addDays } from 'date-fns';

export const handler = async (event, context) => {
  console.log('Lambda Function Started - Request ID:', context.requestId);

  try {
    const numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const chunkedNumbers = _.chunk(numbers, 3);
    const sum = _.sum(numbers);

    const today = new Date();
    const nextWeek = addDays(today, 7);
    const formattedDate = format(today, 'yyyy-MM-dd HH:mm:ss');
    const formattedNextWeek = format(nextWeek, 'yyyy-MM-dd');

    let apiData = null;
    try {
      const response = await axios.get('https://jsonplaceholder.typicode.com/posts/1', {
        timeout: 5000
      });

      apiData = {
        status: response.status,
        data: response.data
      };
    } catch (error) {
      apiData = {
        error: 'API fetch failed',
        message: error.message
      };
    }

    // レスポンスの構築
    const response = {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Lambda function executed successfully',
        librariesUsed: {
          lodash: {
            demo: {
              originalArray: numbers,
              chunked: chunkedNumbers,
              sum: sum
            }
          },
          dateFns: {
            demo: {
              today: formattedDate,
              nextWeek: formattedNextWeek
            }
          },
          axios: apiData
        },
        timestamp: new Date().toISOString(),
        requestId: context.requestId
      }, null, 2)
    };

    console.log('Lambda Function Completed Successfully');
    return response;

  } catch (error) {
    console.error('Lambda function error:', error.message);

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Error executing Lambda function',
        error: error.message,
        timestamp: new Date().toISOString()
      }, null, 2)
    };
  }
};

// ローカルテスト用: このファイルが直接実行された場合のみ実行
if (import.meta.url === `file://${process.argv[1]}`) {
  const testEvent = {};

  const testContext = {
    requestId: 'test-request-id-' + Date.now(),
    functionName: 'test-function',
    functionVersion: '1.0.0'
  };

  console.log('=== ローカルテスト実行 ===\n');

  handler(testEvent, testContext)
    .then(response => {
      console.log('\n=== 実行結果 ===');
      console.log(response.body);
    })
    .catch(error => {
      console.error('\n=== エラー ===');
      console.error(error);
      process.exit(1);
    });
}
